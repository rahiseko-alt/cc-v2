// docs/roadmap.html の base 版と head 版を比べ、変更が JSON の meta（handoff/next/updated 等の
// ナビ情報）だけに収まっているかを判定する。
//   - meta だけの変更（nodes もエンジンHTMLも不変）        → exit 0（＝基準非対象。日々の checkout はここ）
//   - nodes（criteria/verify 含む）やエンジンHTMLに変更あり → exit 1（＝基準対象。門を適用）
//   - パース不能・想定外                                    → exit 1（安全側で対象）
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

try {
  const [, , baseFile, headFile] = process.argv;
  const a = parse(baseFile);
  const b = parse(headFile);
  const nodesEqual = JSON.stringify(a.json.nodes) === JSON.stringify(b.json.nodes);
  const shellEqual = a.shell === b.shell;
  if (nodesEqual && shellEqual) {
    console.log('roadmap.html の変更は meta(handoff/next/updated 等)のみ → 基準非対象');
    process.exit(0);
  }
  console.log(`roadmap.html の変更が meta 以外に及ぶ（nodes変更=${!nodesEqual} / エンジン変更=${!shellEqual}） → 基準対象`);
  process.exit(1);
} catch (e) {
  console.log('判定不能のため安全側で基準対象に倒す: ' + (e && e.message));
  process.exit(1);
}
