# failures（失敗の蓄積ログ / append-only・消さない）

同じ失敗を繰り返さないための**蓄積型**ログ。handoff（`docs/roadmap.html` の `meta.handoff`・毎回上書き）とは
役割が違い、ここは**消さずに積む**。1件＝**日付＋事象＋根因＋教訓**。

---

## 2026-07-22 handoff が別枝で孤児化して消失
- 事象：チェックアウトで handoff を、空の `origin/main` から作り直した別ブランチに書いて push（と自己申告）。その
  ブランチは本編トランクにマージされず、ラベル撤去で孤児化 → コミット(af0d724)が GC で消滅。次セッションは旧 handoff を読んだ。
- 根因：「PR マージ後は default branch から作り直す」を額面通り実行。だが `origin/main` は空の Initial commit で
  本編ではない（本編は claude ブランチの積み上がり）。
- 教訓：handoff は roadmap（`meta.handoff`）に同梱し、本編（毎PRで必ず乗る `docs/roadmap.html`）と一緒にマージする。
  commit/push の自己申告を信じない（SHA の実在を確認する）。
- 補足：実データ上 af0d724 は消滅ではなく、既にマージ済みブランチ `claude/language-granularity-verification-6mr28i`
  の先端に取り残されていた（PR#14 マージ後に余分 push→未取り込み）。次セッションは main から生えたため読めなかった。

## 2026-07-22 stale なローカル参照を鵜呑みにして「消滅」と誤断定
- 事象：`git cat-file -t af0d724` がローカルで「Not a valid object」を返したのを根拠に「af0d724 は GC で消滅」と断言。
  実際は GitHub 上に実在（上記ブランチ先端）。ローカル clone の `origin/main` も stale（fef4360=Initial commit を指す）で、
  「main は空」とも誤断定していた。真の main は cf22e57。
- 根因：ローカルの remote-tracking 参照が古いまま、リモート実データ（GitHub API / `git ls-remote`）で照合せず結論した。
  「本人の自己申告を信じない」を掲げながら、自分のローカル状態を自己申告として鵜呑みにした。
- 教訓：ブランチ/コミットの存否・main の位置は、**ローカルの `origin/*` ではなくリモート実データ**
  （`git ls-remote` / GitHub API `list_branches`）で確認してから断定する。

