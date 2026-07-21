# handoff（次セッションへの特筆事項 / 3行以内・ロードマップ事項は書かない）

サンドボックスは *.vercel.app / vercel.com を組織 egress ポリシーで遮断（403）。Vercel 検証は CI(prod-smoke.yml)＝プロキシ外実機に curl させ run URL を evidence にする。
本番URL=cc-v2-web.vercel.app（scope=rahisekos-projects）。/api/boom は観測性自己テスト用の意図的500ルート（平常は叩かない）。
Vercel ダッシュボード操作(Promote/Redeploy/ログ確認)は master の手作業でしか行えない。素人向けには直リンク＋アドレスバーURLコピーで誘導するのが最速。
