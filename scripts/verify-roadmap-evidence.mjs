#!/usr/bin/env node
// evidence の機械リンタ（“自己採点”を機械で閉じる）。
// docs/roadmap.html の JSON を parse し、全 criteria の非空 evidence が
// 「偽造不能な外部事実」パターンに合致するかを検査する。合致しなければ exit 1。
// あわせて meta.active が実在ノードIDを指すか（stale 防止）も検査する。
//
// 許可する外部事実（AGENTS.md の evidence 規律と一致）:
//   - commit SHA            : 7〜40桁の hex
//   - CI run               : actions/runs/<数字>  もしくは https://.../actions/runs/<数字>
//   - 任意の URL           : http(s)://...（公開URL・run URL・alert URL 等）
//   - デプロイID           : dpl_<英数字>（Vercel）
// スクショ・「レビューした」等の自己申告は不許可（＝これらは非空でも弾く）。

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const roadmapPath = resolve(__dirname, "..", "docs", "roadmap.html");

const EVIDENCE_PATTERNS = [
  /^[0-9a-f]{7,40}$/, // commit SHA
  /^actions\/runs\/\d+$/, // CI run（短縮表記）
  /^https?:\/\/\S+$/, // 任意の外部URL（run/alert/公開URL）
  /^dpl_[A-Za-z0-9]+$/, // Vercel デプロイID
];

function extractRoadmapJson(html) {
  const m = html.match(
    /<script type="application\/json" id="roadmap-data">([\s\S]*?)<\/script>/,
  );
  if (!m) throw new Error("roadmap-data script block not found");
  return JSON.parse(m[1]);
}

function walk(node, visit) {
  visit(node);
  if (Array.isArray(node.children)) {
    for (const child of node.children) walk(child, visit);
  }
}

function main() {
  const html = readFileSync(roadmapPath, "utf8");
  const data = extractRoadmapJson(html);

  const ids = new Set();
  const violations = [];

  for (const root of data.nodes) {
    walk(root, (node) => {
      if (node.id) ids.add(node.id);
      for (const c of node.criteria || []) {
        const ev = (c.evidence ?? "").trim();
        if (ev === "") continue; // 未充足は対象外（☐ のまま）
        const ok = EVIDENCE_PATTERNS.some((re) => re.test(ev));
        if (!ok) {
          violations.push(
            `${node.id}: evidence "${ev}" は外部事実パターンに合致しません（commit SHA / actions/runs/<n> / http(s):// / dpl_ のみ許可）`,
          );
        }
      }
    });
  }

  const active = data.meta?.active;
  if (active && !ids.has(active)) {
    violations.push(
      `meta.active "${active}" は実在ノードIDを指していません（stale pointer）`,
    );
  }

  if (violations.length > 0) {
    console.error("✗ roadmap evidence リンタ: 不正を検出");
    for (const v of violations) console.error("  - " + v);
    process.exit(1);
  }

  console.log(
    `✓ roadmap evidence リンタ: OK（ノード ${ids.size} 件、不正 evidence なし）`,
  );
}

main();
