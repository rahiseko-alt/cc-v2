# apps/web の AGENTS.md（記入済みの実例）

ルート `AGENTS.md` の普遍ルールを継承しつつ、この案件で確定したスタックを宣言する。
これは「初期化フロー（ヒアリング→リサーチ→提案→承認→設定）」を一度通した結果の実例。

## 概要

Next.js（App Router）の Web アプリ。共有 UI は `@repo/ui`（`packages/ui`）を利用する。

## 技術スタック（確定）

- クラウド / ホスティング: Vercel
- 言語 / ランタイム: TypeScript（strict） / Node.js 22
- フレームワーク: Next.js 15（App Router） + React 19
- パッケージ / 依存管理: pnpm（workspace）
- スタイル: Tailwind CSS v4
- DB / データアクセス: 未定
- 認証: 未定
- IaC / デプロイ: Vercel（main へ push で自動デプロイ、Root Directory = `apps/web`）。ビルド設定は `apps/web/vercel.json` に固定（framework=nextjs / install=`pnpm install --frozen-lockfile` / build=`pnpm --filter web build` / output=`.next`）
- テスト: 未定
- Lint / フォーマッタ: ESLint（flat config）

## コマンド

- セットアップ: `pnpm install`
- 開発: `pnpm --filter web dev`
- ビルド: `pnpm --filter web build`
- 型チェック: `pnpm --filter web typecheck`
- Lint: `pnpm --filter web lint`

## この案件固有のルール / メモ

- `any` は原則禁止（避けられない場合は理由をコメント）。
- React は関数コンポーネント + Hooks。スタイルは Tailwind ユーティリティ中心。
- 共有コンポーネントは `packages/ui/src` に置き、`index.ts` から export して `@repo/ui` で使う。
