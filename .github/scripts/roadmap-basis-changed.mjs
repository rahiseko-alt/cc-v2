// docs/roadmap.html の base 版と head 版を比べ、変更を3層に分類して stdout に1トークンで出す。
//   - meta   … meta(handoff/next/updated 等)のみ変更（nodes もエンジンHTMLも不変） → tier-0（門は非対象／日々の checkout）
//   - nodes  … nodes(criteria/verify 含む)が変更（エンジンHTMLは不変）           → tier-1（別ベンダ bot の敵対レビュー）
//   - engine … 描画エンジン(HTML/CSS/JS＝審判の一部)が変更                        → tier-2（人間＝マスター承認）
//   - engine … パース不能・想定外も安全側で engine(=人間) に倒す
// 分類トークンは stdout の**単独最終行**に出す（診断は stderr）。呼び出し側(basis-gate.sh)がこれを読む。
// criteria/verify は全て nodes 配下にあり meta には無いため、「meta のみ変更」は基準変更ではない。
import fs from 'node:fs';

const RE = /<script type="application\/json" id="roadmap-data">([\s\S]*?)<\/script>/;

function parse(path) {
  const html = fs.readFileSync(path, 'utf8');
  const m = html.match(RE);
  if (!m) throw new Error('roadmap-data ブロックが見つからない: ' + path);
  const json = JSON.parse(m[1]);
  // JSON ブロックを丸ごと除いた「エンジン(HTML/CSS/JS)＋外枠」部分
  const shell = html.slice(0, m.index) + html.slice(m.index + m[0].length);
  return { json, shell };
}

function emit(token, msg) {
  if (msg) console.error(msg);
  console.log(token);
}

try {
  const [, , baseFile, headFile] = process.argv;
  const a = parse(baseFile);
  const b = parse(headFile);
  const shellEqual = a.shell === b.shell;
  if (!shellEqual) {
    emit('engine', 'roadmap.html の描画エンジン(HTML/CSS/JS)が変更 → tier-2(人間承認)');
    process.exit(0);
  }
  const nodesEqual = JSON.stringify(a.json.nodes) === JSON.stringify(b.json.nodes);
  if (nodesEqual) {
    emit('meta', 'roadmap.html の変更は meta(handoff/next/updated 等)のみ → tier-0(門は非対象)');
    process.exit(0);
  }
  emit('nodes', 'roadmap.html の nodes(criteria/verify 含む)が変更 → tier-1(別ベンダ bot レビュー)');
  process.exit(0);
} catch (e) {
  emit('engine', '判定不能のため安全側で tier-2(人間) に倒す: ' + (e && e.message));
  process.exit(0);
}
