# 基準凍結の門（第2の目のレビュー＋マスター承認）

`criteria` / `verify`（＝受入基準）や規律に触るPRを、**独立した第2の目が敵対的にレビューし、その反証を
マスターが読んだ上で承認するまで先に進めない**ようにする仕組み。AGENTS.md「基準凍結の門」の実装（運用(2)）。

## 何を門にかけるか
PRの変更に次のいずれかが含まれるとき、門を適用する（それ以外は非対象＝自動pass）:
- `docs/roadmap.html`（ロードマップの正＝criteria/verify）
- `AGENTS.md`（ルート／各階層の規律・スタック宣言）

## 運用フロー (2)
1. **Claude（本人）** が基準変更PRを作り、分解と合格ラインを PR 本文に示す。
2. **第2の目**＝独立サブエージェント `basis-reviewer`（`.claude/agents/basis-reviewer.md`）が、
   分解が **atomic・十分・平易** かを敵対的に審査する（迷えば却下）。
   反証は「**非エンジニアが読める平易な1文**」で出し、**生の反証は PR に記録**として残す。
3. Claude はその反証を平易に翻訳し、マスターに **「GO可 / 直す / 覆す」** を提示する（要約は生記録と照合可能）。
4. **反証があれば止まる（Y）**。解除は次のいずれか:
   - **直す**：反証に対応して分解／合格ラインを修正 → 再レビューで反証が消える
   - **覆す**：マスターが「この反証は当たらない」と**理由を記録して**却下する
5. マスターが納得したら **PRを承認**する。これが門の実体。

## 機械側（basis-gate）は「土管」
- `.github/workflows/basis-gate.yml` がPRのopen/更新/レビュー投稿で走る。
- `.github/scripts/basis-gate.sh` が判定し、**commit status `basis-gate`** を head SHA に記録する。
  - 基準ファイル未変更 → `success`（門は非対象）
  - 基準ファイル変更あり → `.github/basis-reviewers.txt` の必須レビュアーの**現HEADでの最終判定**を読む:
    - 誰かが **変更要求（反証）** → `failure`（＝止まる／Y）
    - 全員 **承認（APPROVED）** → `success`
    - まだ判定なし → `failure`（承認待ち）
  - 判定は **head SHA 紐付きのみ有効**＝中身を変えると旧レビューは無効（stale）。
- **機械は反証の"内容"を判断しない**。承認／変更要求という**フラグ**を中継・強制するだけ。
  中身の当否は 第2の目（AI）と 人間（マスター）が判断する。

## 必須レビュアー（現状）
`.github/basis-reviewers.txt` = **`rahiseko-alt`（マスター）** 1名。
第2の目（サブエージェント）は独立 bot 身元を持てないため機械照合の対象にせず、その反証対応は人間の規律に委ねる。

## 別ベンダ枠の将来差し替え（確認済み・裏取り）
第2の目を**別ベンダの bot** に格上げできる。候補は GitHub App としてPRレビューを出す:
- **`@codex review`**（OpenAI・クラウド。PRに標準のGitHubレビューをbot身元で投稿）
- **Gemini Code Assist**（Google・別モデル系統・個人版は無料）
- CodeRabbit / GitHub Copilot code review / Qodo など

差し替え手順：その bot のログインを `.github/basis-reviewers.txt` に足す（＋botは Approve でなく Comment/変更要求を
出すため、判定を「承認済みか」→「反証が無いか」に合わせる小改修）。**`basis-gate` の乗り物はレビュアー非依存**。
なお GitHub の "required approvals" は bot 承認を数えない仕様のため、bot の判定を効かせる正しい方法は
**本 basis-gate のような"必須ステータスチェック"**（native 承認要件ではない）。

## 有効化に必要な人手（管理者）
1. **branch protection（`main`）を設定**：
   - Require a pull request before merging
   - **Require status checks to pass** に status context **`basis-gate`** を追加
   - **Dismiss stale pull request approvals when new commits are pushed** を有効
2. 設定後、基準変更PRは **反証が残っている間は赤／マスター承認が現HEADに付いて緑** になり、緑までマージ不可。

> ⚠️ プラン制約：**private リポでは、branch protection の"必須化(ハード強制)"は有料プラン（Pro/Team）
> または public 化が要る**。それが無い間、`basis-gate` は**赤/緑の"信号"は出るがマージ物理ブロックはかからない**。
> その場合の実質の歯止めは「基準変更PRはマスターしかマージしない」運用。将来 public 化 or 有料化で `basis-gate`
> を必須ONにすればハード強制へ格上げできる（仕掛けは完成済み）。

## 制限
- fork からのPRはトークンが read-only になり status を書けない。本リポは同一リポの `claude/*` ブランチ運用のため通常は該当しない。
- `pull_request_review` トリガーは既定ブランチ（main）にこのワークフローが入って以降に有効。
