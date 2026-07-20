# AGENTS.md

このファイルはリポジトリ全体の **デフォルトルール** です。すべての AI コーディングツール
（Claude Code / Codex / Cursor / Antigravity ほか）がこのファイルを参照します。

## このファイルの権威

- グローバル設定や個人の慣習とこのファイルが矛盾する場合、**常にこのファイルを優先** する。
- より深いディレクトリに `AGENTS.md` がある場合、そのディレクトリ配下では **近い方が優先**
  （下記「配下ごとの調整」参照）。

## 技術スタック（鉄板デフォルト）

- ランタイム: Node.js 22
- 言語: TypeScript（strict）
- フレームワーク: Next.js（App Router）
- UI: React
- スタイル: Tailwind CSS
- パッケージ管理: pnpm

## コマンド

- セットアップ: `pnpm install`
- 開発サーバー: `pnpm dev`
- 本番ビルド: `pnpm build`
- 本番起動: `pnpm start`
- 型チェック: `pnpm typecheck`（= `tsc --noEmit`）
- Lint: `pnpm lint`
- テスト: `pnpm test`（テスト基盤は各アプリで導入。未導入なら配下 `AGENTS.md` に明記）

## ルール（守ること）

- TypeScript は strict。`any` は原則禁止（避けられない場合は理由をコメントで残す）。
- React は関数コンポーネント + Hooks。
- スタイルは Tailwind のユーティリティで書く（独自 CSS は最小限）。
- 変更後は必ず `pnpm typecheck` と `pnpm lint` を通してからコミットする。
- 秘密情報（API キー等）はコミットしない。`.env*` は Git 管理外。

## やらないこと（禁止）

- 指示のない大規模リファクタリング。
- 依存ライブラリの勝手な追加（必要なら理由を添えて提案する）。
- パッケージマネージャーの混在（pnpm 以外の lockfile を作らない）。

## 配下ごとの調整（オーバーライド）

サブディレクトリに `AGENTS.md` を置くと、そのディレクトリ配下ではそちらが優先される。
このルートは「デフォルト」であり、個別アプリで違うスタックやコマンドにしたい場合は、
そのアプリ直下に `AGENTS.md` を作り、**変えたい項目だけ** を上書きする。
書いていない項目はルートの設定を継承する。

例: `apps/admin/AGENTS.md`

```markdown
# apps/admin の個別ルール（ルートを継承しつつ上書き）

## 技術スタック
- テスト: Vitest + Testing Library

## コマンド
- テスト: `pnpm test`
- 実行: `pnpm --filter admin dev`
```
