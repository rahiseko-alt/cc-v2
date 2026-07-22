# failures（失敗の蓄積ログ / append-only・消さない）

同じ失敗を繰り返さないための**蓄積型**ログ。handoff（`docs/roadmap.html` の `meta.handoff`・毎回上書き）とは
役割が違い、ここは**消さずに積む**。1件＝**日付＋事象＋根因＋教訓**。

---

## 2026-07-22 handoff が既マージ枝に取り残され次セッションに渡らなかった
- 事象：前回チェックアウトで handoff を、PR#14 が既にマージ済みのブランチ（`claude/language-granularity-verification-6mr28i`）
  先端へ余分に1コミット push（`af0d724`）。PR は既にクローズ/マージ済みのため main に取り込まれず、ブランチ上に取り残された。
  次セッションは main（旧 handoff）から生えたため読めなかった（＝消滅ではなく未マージの取り残し）。
- 根因：handoff が本編（毎PRで必ず main に乗る `docs/roadmap.html`）と別ファイル・別経路。マージ済み枝への追い push は main に届かない。
- 教訓：handoff は roadmap（`meta.handoff`）に同梱し、本編と一緒に必ずマージする。commit/push の自己申告を鵜呑みにせず存否を確認する。

## 2026-07-22 stale なローカル参照を鵜呑みにして「消滅」と誤断定
- 事象：`git cat-file -t af0d724` がローカルで「Not a valid object」を返したのを根拠に「af0d724 は消滅」と断言。
  実際は GitHub 上に実在（上記ブランチ先端）。ローカル clone の `origin/main` も stale（fef4360=Initial commit を指す）で、
  「main は空」とも誤断定した。真の main は cf22e57。
- 根因：ローカルの remote-tracking 参照が古いまま、リモート実データ（`git ls-remote` / GitHub API `list_branches`）で照合せず結論した。
  「本人の自己申告を信じない」を掲げながら、自分のローカル状態を自己申告として鵜呑みにした。
- 教訓：ブランチ/コミットの存否・main の位置は、**ローカルの `origin/*` ではなくリモート実データ**で確認してから断定する。
