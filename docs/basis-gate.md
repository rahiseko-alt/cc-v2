# 基準凍結の門（2AI承認ゲート）

`criteria` / `verify`（＝受入基準）や規律に触るPRを、**別系統2AI（Claude と Codex）の
両方が承認するまでマージできない**ようにする仕組み。AGENTS.md「基準凍結の門＝2AIレビュー」の実装。

## 何を門にかけるか
PRの変更に次のいずれかが含まれるとき、門を適用する（それ以外は非対象＝自動pass）:
- `docs/roadmap.html`（ロードマップの正＝criteria/verify）
- `AGENTS.md`（ルート／各階層の規律・スタック宣言）

## 仕組み（機械側）
1. `.github/workflows/basis-gate.yml` がPRのオープン／更新／レビュー投稿で走る。
2. `.github/scripts/basis-gate.sh` が判定し、**commit status `basis-gate`** を head SHA に記録する。
   - 基準ファイル未変更 → `success`（門は非対象）
   - 基準ファイル変更あり → `.github/basis-reviewers.txt` の全員が**現HEADに対して** `APPROVED`
     なら `success`、揃わなければ `failure`（誰の承認待ちかを表示）。
   - 承認は **head SHA 紐付きのみ有効**＝中身を変えると旧承認は無効（stale）。
3. 設定漏れ（`basis-reviewers.txt` がプレースホルダのまま）は **fail-closed**（赤）。

## 有効化に必要な人手（管理者）
このリポの管理者が次を行って初めて「機械強制」になる:

1. **必須レビュアーを記入**：`.github/basis-reviewers.txt` のプレースホルダを、
   Claude と Codex がPR承認する時の実 GitHub ログイン（bot/ユーザー名）に置き換える。
2. **Codex をこのリポに接続**：Codex が同じリポを開いてPRレビュー（Approve / Request changes）を
   残せるようにする。
3. **branch protection（`main`）を設定**：
   - Require a pull request before merging（レビュー必須）
   - **Require status checks to pass** に status context **`basis-gate`** を追加
   - **Dismiss stale pull request approvals when new commits are pushed** を有効
     （中身を変えたら承認をやり直させる）
4. 設定後、基準変更PRは **Claude と Codex 両方の承認が現HEADに揃うまでマージ不可**になる。

## 不一致のとき
片方が Approve・片方が Request changes（＝2AIの判断が割れた）ときは、門は赤のまま。
これは**人間（マスター）が両者の論拠を読み比べて決める**サイン（AGENTS.md の「不一致は人間へ上申」）。

## 制限
- fork からのPRはトークンが read-only になり status を書けない。本リポは同一リポの
  `claude/*` ブランチ運用のため通常は該当しない。
- `pull_request_review` トリガーは既定ブランチ（main）にこのワークフローが入って以降に有効。
