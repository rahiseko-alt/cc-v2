# handoff（次セッションへの特筆事項 / 3行以内・ロードマップ事項は書かない）

WebFetch は docs.github.com / developers.openai.com が 403（組織プロキシ拒否）。サンドボックスは *.vercel.app も遮断（本番検証は CI=prod-smoke.yml でやる）。
リポは public 化済（cc-v2）。本番 URL は GitHub の homepage フィールドに Vercel が自動設定（今回 cc-v2-web.vercel.app を発見）。
CI 実機は vercel.app に到達可。外部到達の検証は必ず GitHub Actions 側に curl させて run URL を evidence にする。
