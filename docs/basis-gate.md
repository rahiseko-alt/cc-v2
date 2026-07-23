# 基準凍結の門（3層ルーティング＋auto-merge）

日常のマージから人間を外しつつ「本人採点の禁止」を守る仕組み。PR が触るファイルを **3層** に分類し、
必要な承認だけを要求する。結果は commit status `basis-gate` に記録し、`auto-merge` ワークフローが緑の PR を
自動マージする。AGENTS.md「検証の規律／承認は3層」の機械実装。

## 3層ルーティング（何を誰が裁くか）

| tier | 対象（PR が触るもの） | 裁定者 | basis-gate |
|------|----------------------|--------|-----------|
| **tier-0** | 実装コード・文章・`docs/roadmap.html` の **meta のみ** 等 | 機械（CI）だけ | 即 `success` |
| **tier-1** | `docs/roadmap.html` の **nodes**（criteria/verify＝合格ライン） | **別ベンダ bot**（第2の目） | bot 反証なしで `success`（bot 未設定時は人間 fallback） |
| **tier-2** | **審判集合**（下記）＝ 審判そのもの／prod 昇格 | **人間（マスター）** | 人間 APPROVED で `success` |

- **審判集合（tier-2）**：`.github/workflows/**`（機械の審判本体）／`.github/scripts/**`（basis-gate・evidence 検査
  ＝強制装置）／`.github/basis-reviewers.txt`・`.github/bot-reviewers.txt`（誰が裁くか）／ルート `AGENTS.md`
  （規律メタルール）／`docs/roadmap.html` の**描画エンジン**（＝roadmap-data JSON 以外の HTML/CSS/JS）。
- **roadmap の分類**は `.github/scripts/roadmap-basis-changed.mjs` が `meta`／`nodes`／`engine` の3トークンで返す
  （meta→tier-0・nodes→tier-1・engine→tier-2）。
- **優先順位**：tier-2 該当があれば最優先で人間。無く nodes 変更のみなら tier-1。どれでもなければ tier-0。

## 運用フロー
1. **Claude（本人）** が PR を作り、基準に触るなら分解と合格ラインを PR 本文に示す。
2. **第2の目**（tier-1＝別ベンダ bot／tier-2＝人間）が **atomic・十分・平易** かを敵対レビューする。
   反証は「**非エンジニアが読める平易な1文**」で出す。
3. **反証があれば止まる（Y）**。解除は「基準を直して反証を消す」か、tier-2 では「マスターが理由を記録して覆す」。
4. 反証が無く承認がそろえば `basis-gate` が `success` になり、CI も緑なら **`auto-merge` が自動でマージ**する。

## 機械側（basis-gate）は「土管」
- `.github/workflows/basis-gate.yml` が PR の open/更新/レビュー投稿で走る。
- `.github/scripts/basis-gate.sh` が3層に分類し、**commit status `basis-gate`** を head SHA に記録する。
  - tier-0 → `success`（門は非対象／auto-merge の対象）。
  - tier-1 → `.github/bot-reviewers.txt` の bot が**現HEADでレビュー済み＆反証(CHANGES_REQUESTED)なし**で `success`。
    bot 未設定（空／placeholder）の間は安全側で `.github/basis-reviewers.txt` の**人間へ fallback**。
  - tier-2 → `.github/basis-reviewers.txt` の必須人間が**全員 APPROVED** で `success`。反証で `failure`、未判定は承認待ち。
  - 判定は **head SHA 紐付きのみ有効**＝中身を変えると旧レビューは無効（stale）。
- **機械は反証の"内容"を判断しない**。承認／変更要求という**フラグ**を中継・強制するだけ。中身の当否は bot／人間が判断する。

## auto-merge（人間をボタンから外す）
- `.github/workflows/auto-merge.yml` が `check_suite`／`status`／`pull_request_review`／`pull_request(label)` で走る。
- main 向け・同一リポ発・非draft・`hold` ラベル無し・mergeable の PR について、
  **commit status(basis-gate/prod-smoke) が combined success かつ CI の check runs が全て success** なら squash マージする。
- tier-2（人間待ち）や tier-1（bot 反証/待ち）の間は `basis-gate` が `failure` なので**自動マージされない**＝門と両立。
- 一時的に自動マージを止めたい PR には **`hold` ラベル**を付ける。
- private 無料プランでも動くよう、branch protection の auto-merge 機能ではなく **トークンによる明示マージ**で実装。

## 必須レビュアー台帳（現状）
- **人間**：`.github/basis-reviewers.txt` = **`rahiseko-alt`（マスター）** 1名（tier-2＋bot未設定時の tier-1 fallback）。
- **bot**：`.github/bot-reviewers.txt` = **未設定（placeholder）**。別ベンダ bot を入れると tier-1 が人間から外れる。

## 別ベンダ bot（第2の目）の導入（tier-1 を人間から外す）
候補は GitHub App として PR にレビューを出す：
- **`@codex review`**（OpenAI・PRに標準のGitHubレビューをbot身元で投稿）
- **Gemini Code Assist**（Google・個人版は無料）／ CodeRabbit / Qodo など

手順：その bot をリポにインストールし、**ログインを `.github/bot-reviewers.txt` に記入**する（placeholder と差し替え）。
basis-gate は bot の「反証(CHANGES_REQUESTED)が無いか」を機械照合する（bot は Approve を出せない場合があるため、
判定は「承認済みか」ではなく「現HEADでレビュー済み＆反証なしか」）。**`basis-gate` の乗り物はレビュアー非依存**。
なお GitHub の "required approvals" は bot 承認を数えない仕様のため、効かせる正しい方法は本 basis-gate のような
**"必須ステータスチェック"**（native 承認要件ではない）。

## 有効化に必要な人手（管理者）
1. **branch protection（`main`）を設定**：
   - Require a pull request before merging
   - **Require status checks to pass** に status context **`basis-gate`** と CI／`roadmap-required` を追加
   - **Dismiss stale pull request approvals when new commits are pushed** を有効
2. 設定後、tier-1/2 の PR は **反証が残る間は赤／承認が現HEADに付いて緑** になり、緑まで（auto-merge も含め）進めない。

> ⚠️ プラン制約：**private リポでは branch protection の"必須化(ハード強制)"は有料プラン（Pro/Team）または public 化が要る**。
> それが無い間、`basis-gate` は**赤/緑の"信号"は出るがマージ物理ブロックはかからない**。ただし `auto-merge` は
> basis-gate=success を条件にするので、**tier-1/2 が緑になるまで自動マージは走らない**（ソフトには機能する）。
> 将来 public 化 or 有料化で `basis-gate` を必須 ON にすればハード強制へ格上げできる（仕掛けは完成済み）。

## 制限
- fork からのPRはトークンが read-only になり status を書けない。本リポは同一リポの `claude/*` ブランチ運用のため通常は該当しない。
- `status`／`check_suite`／`pull_request_review` トリガーは既定ブランチ（main）にワークフローが入って以降に有効。
- 段階境界（sandbox→dev→prod）の **prod 昇格ゲート本物化（A案）は次の一手**。現状 main→本番は Vercel 自動デプロイのため、
  「prod 昇格＝人間の関所」を本物にするには main を preview 相当へ降格し `prod-*` タグ昇格＋GitHub Environment 承認へ移す。
