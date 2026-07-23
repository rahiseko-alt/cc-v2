#!/usr/bin/env bash
# 基準凍結の門番（3層ルーティング）。AGENTS.md「検証の規律／承認は3層」の機械実装。
# PR が触るファイルを3層に分類し、必要な承認だけを head SHA に対して要求する。
#
#   tier-0（機械だけ／人間ゼロ）… 実装コード・文章・roadmap の meta のみ 等。
#                                  → basis-gate は即 success（CI 緑で auto-merge の対象）。
#   tier-1（別ベンダ bot の敵対レビュー／人間ゼロ）… roadmap の nodes(criteria/verify) 変更。
#                                  → .github/bot-reviewers.txt の bot が「反証なし」で success。
#                                    bot 未設定の間だけ安全側で人間(basis-reviewers.txt)へ fallback。
#   tier-2（人間＝マスター承認）  … 審判集合＝ .github/workflows/** ・ .github/scripts/** ・
#                                  reviewers 台帳 ・ ルート AGENTS.md ・ roadmap の描画エンジン ・ prod 昇格。
#                                  → basis-reviewers.txt の必須人間が全員 APPROVED で success。
#
# 機械は「反証の"内容"」は判断しない。人間/bot が出した判定フラグ（承認/変更要求）を中継・強制するだけ（土管）。
# 結果を commit status `basis-gate` として head SHA に記録する。判定は head SHA 紐付きのみ有効＝stale 尊重。
# 機械強制は branch protection で status context `basis-gate` を必須にして初めて有効。
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN required}"
: "${REPO:?REPO required}"
: "${PR:?PR required}"
: "${HEAD_SHA:?HEAD_SHA required}"
: "${BASE_SHA:?BASE_SHA required}"

CONTEXT="basis-gate"
HUMAN_CONFIG=".github/basis-reviewers.txt"
BOT_CONFIG=".github/bot-reviewers.txt"

set_status() {
  local state="$1" desc="$2"
  desc="${desc:0:140}"  # description は140字上限
  gh api -X POST "repos/$REPO/statuses/$HEAD_SHA" \
    -f state="$state" -f context="$CONTEXT" -f description="$desc" >/dev/null
}

# 台帳を読み込む（コメント/空行/空白を除去）。placeholder(REPLACE_WITH_) は「未設定」とみなす。
read_reviewers() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -vE '^\s*(#|$)' "$file" | tr -d ' \t\r' | grep -vE '^REPLACE_WITH_' || true
}

# あるログインの「現 HEAD での最終判定」を返す（COMMENTED は無視して APPROVED/CHANGES_REQUESTED の last）。
latest_state() {
  local login="$1"
  gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
    --jq "[ .[] | select(.commit_id==\"$HEAD_SHA\") | select(.user.login==\"$login\") \
            | select(.state==\"APPROVED\" or .state==\"CHANGES_REQUESTED\") | .state ] | last // \"NONE\""
}

# bot が「現 HEAD で何らかのレビューを出したか」（COMMENTED も含む）。反証なしの pass 判定に使う。
bot_reviewed_at_head() {
  local login="$1"
  gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
    --jq "[ .[] | select(.commit_id==\"$HEAD_SHA\") | select(.user.login==\"$login\") ] | length"
}

# 人間ゲート：必須人間が全員 APPROVED なら success、反証(CHANGES_REQUESTED)で failure、未判定は承認待ち。
enforce_human_gate() {
  local tier="$1"; shift
  local reviewers=("$@")
  if [ "${#reviewers[@]}" -eq 0 ]; then
    set_status failure "$tier: 門番未設定（$HUMAN_CONFIG に必須人間の実ログインを記入せよ）"
    echo "human reviewers not configured"; exit 1
  fi
  local objections=() pending=() approved=()
  local r st
  for r in "${reviewers[@]}"; do
    st="$(latest_state "$r")"
    case "$st" in
      APPROVED)          approved+=("$r") ;;
      CHANGES_REQUESTED) objections+=("$r") ;;
      *)                 pending+=("$r") ;;
    esac
  done
  echo "[$tier] 承認:${approved[*]:-なし} / 反証:${objections[*]:-なし} / 待ち:${pending[*]:-なし}"
  if [ "${#objections[@]}" -gt 0 ]; then
    set_status failure "$tier 反証あり(要対応): $(IFS=,; echo "${objections[*]}") — 直すか、マスターが理由付きで承認し直す"
    echo "objections stand"; exit 1
  fi
  if [ "${#pending[@]}" -gt 0 ]; then
    set_status failure "$tier 承認待ち: $(IFS=,; echo "${pending[*]}")（現HEADへの承認のみ有効）"
    echo "pending approvals"; exit 1
  fi
  set_status success "$tier 承認そろい: $(IFS=,; echo "${approved[*]}")"
  echo "gate passed ($tier)"; exit 0
}

# bot ゲート：必須 bot が全員「現HEADでレビュー済み かつ 反証(CHANGES_REQUESTED)なし」なら success。
enforce_bot_gate() {
  local bots=("$@")
  local objections=() pending=() ok=()
  local b st n
  for b in "${bots[@]}"; do
    st="$(latest_state "$b")"
    if [ "$st" = "CHANGES_REQUESTED" ]; then
      objections+=("$b"); continue
    fi
    n="$(bot_reviewed_at_head "$b")"
    if [ "${n:-0}" -gt 0 ]; then
      ok+=("$b")           # 反証なしの実レビューが現HEADに存在
    else
      pending+=("$b")      # まだ現HEADをレビューしていない
    fi
  done
  echo "[tier-1/bot] 反証なし:${ok[*]:-なし} / 反証:${objections[*]:-なし} / 待ち:${pending[*]:-なし}"
  if [ "${#objections[@]}" -gt 0 ]; then
    set_status failure "tier-1 bot 反証あり: $(IFS=,; echo "${objections[*]}") — 基準を直して反証を消す"
    echo "bot objections stand"; exit 1
  fi
  if [ "${#pending[@]}" -gt 0 ]; then
    set_status failure "tier-1 bot レビュー待ち: $(IFS=,; echo "${pending[*]}")（現HEADへのレビューのみ有効）"
    echo "bot review pending"; exit 1
  fi
  set_status success "tier-1 bot 反証なし: $(IFS=,; echo "${ok[*]}")"
  echo "gate passed (tier-1 bot)"; exit 0
}

# 1) 変更ファイル一覧
FILES="$(gh api "repos/$REPO/pulls/$PR/files" --paginate --jq '.[].filename')"

# 2) tier-2（審判集合）に触れているか。＝「審判そのもの」を変えるファイル。
#    (a) 門・CI・レビュア台帳・規律の本体
tier2=no
if grep -qxE 'AGENTS\.md' <<<"$FILES"; then tier2=yes; fi                 # ルート AGENTS.md のみ
if grep -qE '^\.github/workflows/' <<<"$FILES"; then tier2=yes; fi
if grep -qE '^\.github/scripts/' <<<"$FILES"; then tier2=yes; fi
if grep -qxE '\.github/basis-reviewers\.txt' <<<"$FILES"; then tier2=yes; fi
if grep -qxE '\.github/bot-reviewers\.txt' <<<"$FILES"; then tier2=yes; fi
#    (b) 「CI が緑と判定する定義そのもの」＝審判の中身。ここを緩める＝審判を骨抜きにする、なので人間必須。
#        各 package.json の scripts / 直下 scripts/(evidence 偽造検査器を含む) / 型・lint・test・依存・
#        ランタイム固定の設定。実装コード本体(apps/**/src 等)は tier-0 のまま自動流通する。
if grep -qE '(^|/)package\.json$' <<<"$FILES"; then tier2=yes; fi
if grep -qE '^scripts/' <<<"$FILES"; then tier2=yes; fi
if grep -qE '(^|/)tsconfig[^/]*\.json$' <<<"$FILES"; then tier2=yes; fi
if grep -qE '(^|/)vitest\.config\.[cm]?[jt]s$' <<<"$FILES"; then tier2=yes; fi
if grep -qE '(^|/)eslint\.config\.[cm]?[jt]s$' <<<"$FILES"; then tier2=yes; fi
if grep -qE '(^|/)\.eslintrc' <<<"$FILES"; then tier2=yes; fi
if grep -qxE 'pnpm-workspace\.yaml' <<<"$FILES"; then tier2=yes; fi
if grep -qxE 'pnpm-lock\.yaml' <<<"$FILES"; then tier2=yes; fi
if grep -qxE '\.node-version' <<<"$FILES"; then tier2=yes; fi
if grep -qxE '\.tool-versions' <<<"$FILES"; then tier2=yes; fi
if grep -qxE '\.npmrc' <<<"$FILES"; then tier2=yes; fi

# 3) roadmap.html 変更の分類（meta / nodes / engine）。engine は tier-2、nodes は tier-1。
roadmap_class=none
if grep -qxE 'docs/roadmap\.html' <<<"$FILES"; then
  if gh api "repos/$REPO/contents/docs/roadmap.html?ref=$BASE_SHA" --jq '.content' 2>/dev/null | base64 -d > /tmp/base_roadmap.html \
     && gh api "repos/$REPO/contents/docs/roadmap.html?ref=$HEAD_SHA" --jq '.content' 2>/dev/null | base64 -d > /tmp/head_roadmap.html \
     && [ -s /tmp/base_roadmap.html ] && [ -s /tmp/head_roadmap.html ]; then
    roadmap_class="$(node .github/scripts/roadmap-basis-changed.mjs /tmp/base_roadmap.html /tmp/head_roadmap.html | tail -n1)"
  else
    echo "roadmap.html の base/head 取得に失敗 → 安全側で engine(tier-2) に倒す"
    roadmap_class="engine"
  fi
  echo "roadmap 分類: $roadmap_class"
  if [ "$roadmap_class" = "engine" ]; then tier2=yes; fi
fi

# 4) ルーティング（tier-2 が最優先。次に tier-1、どれでもなければ tier-0）。
mapfile -t HUMANS < <(read_reviewers "$HUMAN_CONFIG")
mapfile -t BOTS   < <(read_reviewers "$BOT_CONFIG")

if [ "$tier2" = yes ]; then
  echo "判定: tier-2（審判集合／prod 昇格系）→ 人間承認"
  enforce_human_gate "tier-2" "${HUMANS[@]}"
fi

if [ "$roadmap_class" = "nodes" ]; then
  if [ "${#BOTS[@]}" -gt 0 ]; then
    echo "判定: tier-1（roadmap nodes＝基準変更）→ 別ベンダ bot の敵対レビュー"
    enforce_bot_gate "${BOTS[@]}"
  else
    echo "判定: tier-1 だが bot 未設定 → 安全側で人間へ fallback"
    enforce_human_gate "tier-1(bot未設定→人間fallback)" "${HUMANS[@]}"
  fi
fi

echo "判定: tier-0（機械だけ）→ 承認不要。CI 緑で auto-merge 対象。"
set_status success "tier-0: 審判に触れず（機械のみ／CI 緑で auto-merge 対象）"
exit 0
