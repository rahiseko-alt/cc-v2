# apps/web の個別ルール

ルート `AGENTS.md`（Node/TS/Next/React/Tailwind/pnpm）を継承する。
ここでは、このアプリ固有の項目だけを上書き・追記する。

## コマンド（このアプリ内で実行）

- 開発: `pnpm --filter web dev`
- ビルド: `pnpm --filter web build`

## メモ

- 共有 UI は `@repo/ui` から import する（`packages/ui`）。
- 新しい共有コンポーネントは `packages/ui/src` に置き、`index.ts` から export する。
