# handoff（次セッションへの特筆事項 / 3行以内・ロードマップ事項は書かない）

サンドボックスは *.vercel.app / vercel.com を egress 遮断（403）。Vercel 検証は CI(prod-smoke.yml)＝プロキシ外実機に curl させ run URL を evidence にする。Dashboard 操作(Promote/Redeploy/ログ)は master 手作業のみ。
basis-gate は自己承認デッドロック：PR 作成者＝唯一の必須承認者 rahiseko-alt が重なり GitHub 仕様で自己承認不可→毎回 admin override で着地。恒久策=別身元レビュアー(@codex review / Gemini / CodeRabbit)を .github/basis-reviewers.txt に追加＝未着手。
次回の主題＝「言語化（state/criteria の分解設計）」を議論：粒度線・分解基準の案件内不統一（G-3-1 だけ子分割、他は葉に複数 criteria 同居）をどう揃えるか等。
