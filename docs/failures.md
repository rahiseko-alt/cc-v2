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

## 2026-07-22 roadmap-required の必須チェック名を job 名≠登録名で登録し、全PRをブロック
- 事象：`roadmap-required` を必須チェックに登録する際、登録名を **workflow 名**「roadmap-required」にした。だが GitHub Actions
  が報告するチェック名は **job 名**「PRにroadmap更新があるか（例外なし）」。両者が食い違い、必須コンテキスト「roadmap-required」が
  永久に未報告 → roadmap を更新した正当なPRを含め**全PRがマージ不能**（`405 Required status check "roadmap-required" is expected`）。
- 根因：Actions の必須チェック名は **job 名（check run 名）** と一致させる必要があるのに workflow 名で登録した。加えて
  「#17 が blocked」を「必須化が正しく機能」と早合点し、**pass→merge できることを確認せず「検証済み」と報告**した。
- 対処：job の `name` を `roadmap-required` に改名して報告名を登録名に一致させ、roadmap 更新PR(#18)が緑通過→マージ成立で実証。
- 教訓：必須チェックは「**blocked を観測」だけでなく「pass して merge できる**」ことまで実証して初めて"効く"証拠になる。
  GitHub Actions の必須チェックは `jobs.<id>.name` を登録名に一致させる。

## 2026-07-23 粒度ルールの「機械的判定手順」を語の単位を揃えずに書き、合格例と自己矛盾させた
- 事象：AGENTS.md の粒度ルールを「原子まで分解」で AI 解釈がぶれない形へ改訂する際、判定手順を
  ①「verify が『かつ』(=`&&`)で2本以上に割れるか」②「独立2つ以上の理由で落ちうるか」で書いた。だが直後の合格例
  `typecheck && lint && test`（=1葉）に literal 適用すると、①は `&&`×3 で YES、②は型/lint/test の3独立原因で YES となり
  「割れ」＝逆判定。手順どおり読む AI と例に従う AI で結論が割れ、狙い（解釈ぶれ排除）を自壊させた。第2の目(basis-reviewer)が反証。
- 根因：停止条件の真の単位は「独立して落ちうる**受入事実**」なのに、判定手順を「`&&` の数／失敗原因の数」という
  **別の単位**で書いた。事実(fact)と、その検証手段（コマンド）・内部失敗原因(reason)を混同した。
- 対処：判定を「その verify は独立して落ちうる**受入事実**を2つ以上含むか？」の1問へ統一。受入事実＝マスターが独立に
  受け入れ判定したい結果／能力と定義し、複合コマンド=1事実の例と、secret scanning＋push protection=2事実の例を手順内に明示。
  basis-reviewer.md の atomic 定義も同じ1問へ整合。
- 教訓：ルールの「機械的判定」は、数える**単位**を規律本体（=受入事実）と厳密に一致させる。コマンド数・`&&`・失敗原因は
  代理指標であって単位ではない。判定手順を書いたら、必ず既存の合格例に literal 適用して逆判定が出ないか自己テストする。

## 2026-07-23 承認3層化で「審判集合」を狭く定義し、AIが自分のCIを緩められる裏口を開けた（マージ前に第2の目が捕捉）
- 事象：承認負担の構造改革B案で審判集合（tier-2＝人間必須）を `.github/workflows/**`・`.github/scripts/**`・reviewers台帳・
  ルートAGENTS.md・roadmap描画エンジンだけで定義した。だが CI の「緑」の定義を実際に決めるのは各 `package.json` の
  `test`/`lint` scripts・直下 `scripts/verify-roadmap-evidence.mjs`（evidence偽造検査器）・`tsconfig*`/`pnpm-lock`/`.node-version` 等で、
  これらが tier-0 に落ちていた。AI が `"test":"echo ok"` へ書き換えたPRが人間もbotも通さず自分で緩めたCIで緑になり
  auto-merge される裏口。＝本改革の目的（本人採点の禁止）を正面から破る穴。第2の目(basis-reviewer)が反証し objection。
- 根因：「審判＝審判を動かす仕組み(workflows/scripts)」とだけ捉え、「審判＝緑の判定基準そのもの(scripts本体/config/依存固定)」を
  取りこぼした。守るべき対象を"入れ物"で列挙し"中身"を落とした。特に evidence 検査器が `.github/scripts/` でなく直下 `scripts/` に
  在ることを実測せず、名前の近さで被覆したつもりになった。
- 対処：tier-2 に各 `package.json`・`^scripts/`・`tsconfig*`/`vitest`/`eslint`/`pnpm-workspace`/`pnpm-lock`/`.node-version`/
  `.tool-versions`/`.npmrc` を追加（basis-gate.sh・AGENTS.md・docs/basis-gate.md を同期）。実装コード本体(apps/**/src)は tier-0 のまま。
  併せて auto-merge の自己チェック除外を部分一致→完全一致(job名 `auto-merge`)へ、skipped を緑扱いしない強化も実施。
- 教訓：「AI が自分の合格を偽造できる経路」を塞ぐときは、審判を動かす仕組みだけでなく**緑の判定基準を決める全ファイル**
  （scripts本体・各config・依存/ランタイム固定）まで含める。パスは思い込みでなく `git ls-files` で実測して被覆を確認する。
  基準を凍結する変更は必ず第2の目に敵対レビューさせてからマージへ回す（今回それが穴を捕捉した＝門が機能した実例）。

## 2026-07-23 branch protection 未設定のまま tier-2 PR(#26)が赤の basis-gate を無視して手動マージされ、動かない bot が本番規律に載った
- 事象：tier-1 の第2の目に CodeRabbit を選定・導入(GitHub App=All repos+write、app.coderabbit.ai に cc-v2 接続)まで済ませ、
  `.github/bot-reviewers.txt` を coderabbitai[bot] に登録する PR#26 を出した。だが CodeRabbit は 3回のトリガー＋新コミットにも
  一切レビューを投稿せず（実稼働未確認）。その状態で PR#26 が main に**マージ**された。basis-gate は「tier-2 承認待ち」で赤だったが、
  **branch protection 未設定のため物理ブロックが効かず手動マージが通った**。結果、動かない bot が tier-1 レビュアーとして本番規律に載り、
  次の tier-1 PR が「存在しない bot のレビュー待ち」で永久固着する footgun 化。翌 handoff PR で placeholder に戻して是正。
- 根因：①門を「赤/緑の信号」までしか作らず、**物理強制（required status check）を有効化しないまま実運用に入った**。ソフト信号は
  人が無視できる。②レビューbotを「導入・接続＝稼働」と早合点し、**実際にPRへレビューを1件投稿することを確認する前に**登録PRを進めた。
  ③basis-gate.sh の bot ゲートに「レビュー待ちのタイムアウト/フォールバック」が無く、登録された bot が沈黙すると tier-1 が固着する。
- 対処：bot-reviewers.txt を placeholder へ戻し tier-1 を人間 fallback に復帰。次セッション最優先で branch protection を設定し
  basis-gate 等を必須チェック化（check名=job名一致）。CodeRabbit は実レビューを1件確認できるまで登録しない方針を明記。
- 教訓：門は「信号を出す」だけでは守れない。**物理強制(branch protection の required status check)を入れて初めて"効く"**。
  外部レビューbotは「導入した」ではなく「実際にPRへレビューを投稿した」ことを外部事実で確認してから規律に組み込む。
  沈黙する必須レビュアーは gate を固着させるので、登録は"実稼働の証拠"とセットにする。
