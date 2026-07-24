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

- **審判集合（tier-2）**：AI が自分の判定を骨抜きにできる所を全部含める。
  - **門・CI・台帳・規律の本体**：`.github/workflows/**`（機械の審判本体）／`.github/scripts/**`／
    `scripts/**`（`verify-roadmap-evidence.mjs`＝evidence 偽造検査器を含む）／`.github/basis-reviewers.txt`・
    `.github/bot-reviewers.txt`（誰が裁くか）／`.coderabbit.yaml`（tier-1 bot が**どう裁くか**＝`request_changes_workflow` 等）／
    ルート `AGENTS.md`（規律メタルール）／`docs/roadmap.html` の**描画エンジン**（＝roadmap-data JSON 以外の HTML/CSS/JS）。
  - **「緑の定義」そのもの**：各 `package.json` の scripts（`test`/`lint` 等）／`tsconfig*.json`／`vitest.config.*`／
    `eslint.config.*`／`pnpm-workspace.yaml`／`pnpm-lock.yaml`／`.node-version`／`.tool-versions`／`.npmrc`。
    実装コード本体（`apps/**/src` 等）は tier-0 のまま自動流通する。
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
- **bot**：`.github/bot-reviewers.txt` = **`coderabbitai[bot]`（CodeRabbit）**。tier-1 はこの bot が裁く（人間から外れる）。
  bot が実レビューを出せない間は tier-1 が緑にならないため、下記 CodeRabbit セットアップの完了が前提。

## 別ベンダ bot（第2の目）＝CodeRabbit（tier-1 を人間から外す）
採用は **CodeRabbit**（公開リポ無料・bot 身元 `coderabbitai[bot]`）。理由：3候補（CodeRabbit / Gemini Code Assist /
OpenAI Codex）のうち **GitHub の formal review "Request changes"(CHANGES_REQUESTED) を自動で出す**ことを公式サポートするのは
CodeRabbit のみ（Gemini はコメント型で Request changes を出さず不適、Codex は有料＋保証が弱い）。

basis-gate は bot の「現HEADでレビュー済み＆反証(CHANGES_REQUESTED)なし」を機械照合する（bot は Approve を出せない場合が
あるため、判定は「承認済みか」ではなく「レビュー済み＆反証なしか」）。**`basis-gate` の乗り物はレビュアー非依存**。
なお GitHub の "required approvals" は bot 承認を数えない仕様のため、効かせる正しい方法は本 basis-gate のような
**"必須ステータスチェック"**（native 承認要件ではない）。

### CodeRabbit セットアップ（管理者・一度きり）
1. GitHub Marketplace で **CodeRabbit を当リポにインストール**（All または当リポを選択）。
2. **CodeRabbit ダッシュボードで当リポを ON**。
3. GitHub リポ **Settings → Moderation options → Code review limits を無効化**（有効だと bot が formal レビューを submit
   できない＝無反応の主因。組織があれば組織側設定も無効化）。
4. リポルートの **`.coderabbit.yaml`** で **`reviews.request_changes_workflow: true`**（既定 false＝COMMENT のみで反証が出ず
   ゲートが素通りになるため必須）。このファイルは審判集合(tier-2)として凍結済み。
5. 完了確認：tier-1 相当の PR（roadmap の nodes 変更）に `coderabbitai[bot]` のレビューが現HEADに付き、`basis-gate` が緑になること。
   反応しない時の切り分け：App 未インストール／ダッシュボード OFF／PR が draft／`base_branches` 対象外／Code review limits 有効
   ／レート制限 → `@coderabbitai review` で手動発火。どうしても不可なら `.github/bot-reviewers.txt` を placeholder に戻し
   tier-1 を人間 fallback（稀なので許容）。

## 有効化に必要な人手（管理者）＝物理強制 ON（Ruleset 推奨）

当リポは**公開済み**なので Ruleset / branch protection は**無料**で使える。**Ruleset を推奨**（日本語・記号・スペース入りの
チェック名を、まだ走っていなくても手入力で必須登録できる。従来型 branch protection は「直近7日に実際に走ったチェック」しか
選べず不便）。

**手順（GitHub → リポ Settings → Rules → Rulesets → New ruleset → New branch ruleset）**：
1. **Ruleset name**：`main-protect`
2. **Enforcement status**：**Active**（既定 Disabled なので必ず変更）
3. **Bypass list**：**何も追加しない**（＝リポ管理者本人もルールに従う。手動マージの裏口を塞ぐ核心）
4. **Target branches → Add target → Include default branch**（`main`）
5. **Require a pull request before merging** を ON、**Required approvals = 0**
   （※ **Require approvals を付けてはいけない**。tier-0 は formal Approve を持たず承認は `basis-gate` に一元化しているため、
   付けると自作 auto-merge の GITHUB_TOKEN マージが**永久ブロック**される）
6. **Require status checks to pass** を ON にし、次の**4つだけ**を1つずつ入力して＋（**名前完全一致**）：
   - `basis-gate`（commit status context）
   - `typecheck / lint / test / build`（CI quality の job 名）
   - `起動スモーク (build → start → curl 200 + marker)`（CI smoke の job 名）
   - `roadmap-required`（job 名）
7. **Block force pushes** は既定 ON のまま → **Create**

**必須にしてはいけないもの**：
- `prod 200 + marker`（prod-smoke）… `pull_request` で走らず本番 URL 反映後に緑になる性質。必須化すると鶏卵で詰む。
- `auto-merge` … マージ実行役。必須化すると自己デッドロック。
- **Require approvals / CODEOWNERS** … 上記5の通り GITHUB_TOKEN マージを殺す。

設定後、tier-1/2 の PR は **反証が残る間は赤／承認・レビューが現HEADに付いて緑** になり、緑まで（auto-merge も含め）
物理的に進めない。自作 auto-merge（GITHUB_TOKEN の `gh pr merge`）は必須チェックをバイパスしない（緑で通り・赤で拒否）。

> 補足：かつては private リポの必須化に有料プランが要ったが、**公開化により無料でハード強制が可能**になった。
> `basis-gate` を必須にすることで、赤（tier-2 承認待ち等）の PR は手動マージも含め物理ブロックされる。

## 制限
- fork からのPRはトークンが read-only になり status を書けない。本リポは同一リポの `claude/*` ブランチ運用のため通常は該当しない。
- `status`／`check_suite`／`pull_request_review` トリガーは既定ブランチ（main）にワークフローが入って以降に有効。
- 段階境界（sandbox→dev→prod）の **prod 昇格ゲート本物化（A案）は次の一手**。現状 main→本番は Vercel 自動デプロイのため、
  「prod 昇格＝人間の関所」を本物にするには main を preview 相当へ降格し `prod-*` タグ昇格＋GitHub Environment 承認へ移す。
