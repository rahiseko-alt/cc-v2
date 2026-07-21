# 基準凍結の門（2AIレビュー＋マスター承認）

`criteria` / `verify`（＝受入基準）や規律に触るPRを、**Claude と Codex の2つの独立した
レビュー意見をマスターが読んだ上で承認するまでマージできない**ようにする仕組み。
AGENTS.md「基準凍結の門」の実装（運用 (B)）。

## 何を門にかけるか
PRの変更に次のいずれかが含まれるとき、門を適用する（それ以外は非対象＝自動pass）:
- `docs/roadmap.html`（ロードマップの正＝criteria/verify）
- `AGENTS.md`（ルート／各階層の規律・スタック宣言）

## 運用フロー (B)
1. **Claude** が基準変更PRを作り、判定と論拠を **PR本文／レビュー**に残す。
2. **Codex** に同じPRを開かせ、独立した判定を **PRコメント**に残させる（敵対的に：atomic でない／不十分な点を探す）。
3. **マスター**が Claude と Codex の両意見を読む。
   - 2つが割れた（片方が却下）ときは、**両者の論拠を読み比べてマスターが決める**。
4. 納得したら、マスターが **PRを承認**する。これが門の実体。

## 仕組み（機械側）
- `.github/workflows/basis-gate.yml` がPRのopen/更新/レビュー投稿で走る。
- `.github/scripts/basis-gate.sh` が判定し、**commit status `basis-gate`** を head SHA に記録する。
  - 基準ファイル未変更 → `success`（門は非対象）
  - 基準ファイル変更あり → `.github/basis-reviewers.txt` の必須承認者（＝マスター `rahiseko-alt`）が
    **現HEADに対して** `APPROVED` なら `success`、無ければ `failure`。
  - 承認は **head SHA 紐付きのみ有効**＝中身を変えると旧承認は無効（stale）。

> 注：Codex の意見コメントは機械照合しない（このリポの Codex はローカル実行でマスター権限の身元のため、
> 独立 bot として自動判定できない）。「2AIを読んでから承認したか」はマスターの規律に委ねる。

## 有効化に必要な人手（管理者）
1. **branch protection（`main`）を設定**：
   - Require a pull request before merging
   - **Require status checks to pass** に status context **`basis-gate`** を追加
   - **Dismiss stale pull request approvals when new commits are pushed** を有効
2. 設定後、基準変更PRは **マスターの承認が現HEADに付くまでマージ不可**になる。

> `.github/basis-reviewers.txt` の承認者は既に `rahiseko-alt`（マスター）に設定済み。
> 将来 Codex をクラウドの独立 bot 身元で使えるようにしたら、ここに Codex のログインを足して
> 「2つの承認」を機械必須にする形へ引き上げられる。

## 制限
- fork からのPRはトークンが read-only になり status を書けない。本リポは同一リポの
  `claude/*` ブランチ運用のため通常は該当しない。
- `pull_request_review` トリガーは既定ブランチ（main）にこのワークフローが入って以降に有効。
