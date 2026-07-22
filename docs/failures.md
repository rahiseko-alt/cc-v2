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
  commit/push の自己申告を信じない（SHA の実在を `git cat-file -t` で確認する）。
