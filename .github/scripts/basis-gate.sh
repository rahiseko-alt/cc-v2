#!/usr/bin/env bash
# 基準凍結の門番（2AIレビュー＋マスター承認・運用(2)）。
# docs/roadmap.html / AGENTS.md 系（＝criteria/verify・規律）に触るPRについて、
# .github/basis-reviewers.txt に列挙した必須レビュアーの「現HEADでの最終判定」を読み、
# 反証(CHANGES_REQUESTED)があれば止め、全員承認(APPROVED)なら通す。
# 結果を commit status `basis-gate` として head SHA に記録する。
#
# 機械は「反証の"内容"」は判断しない。AI/人間が出した判定フラグ（承認/変更要求）を
# 中継・強制するだけ（土管）。中身の当否は AI レビュアーと人間（マスター）が判断する。
#
# 運用(2)：
#   - 第2の目＝独立サブエージェント basis-reviewer（.claude/agents/basis-reviewer.md）が
#     敵対的にレビューし、反証は「非エンジニアが読める平易な1文」で出す。生記録はPRに残す。
#   - basis-reviewers.txt の必須レビュアーは当面マスター1名（rahiseko-alt）。第2レビューの
#     反証は人間が読んで対応する運用（サブエージェントは独立bot身元を持てないため機械照合しない）。
#   - 将来、別ベンダの bot（例：@codex review / Gemini Code Assist）を導入したら、その bot の
#     ログインを basis-reviewers.txt に足すだけで、本スクリプトがその bot の反証/承認を機械照合する。
#
# 機械強制は branch protection で status context `basis-gate` を必須にして初めて有効。
# 判定は head SHA 紐付きのみ有効＝中身を変えると旧レビューは無効(stale)。
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN required}"
: "${REPO:?REPO required}"
: "${PR:?PR required}"
: "${HEAD_SHA:?HEAD_SHA required}"
: "${BASE_SHA:?BASE_SHA required}"

CONTEXT="basis-gate"
CONFIG=".github/basis-reviewers.txt"

set_status() {
  local state="$1" desc="$2"
  desc="${desc:0:140}"  # description は140字上限
  gh api -X POST "repos/$REPO/statuses/$HEAD_SHA" \
    -f state="$state" -f context="$CONTEXT" -f description="$desc" >/dev/null
}

# 1) 基準に触れているか判定（触れていなければ門は非対象＝pass）
#    - AGENTS.md 変更          → 常に基準対象
#    - docs/roadmap.html 変更  → meta(handoff/next/updated 等)のみなら非対象、nodes/エンジンに触れば対象
#      （criteria/verify は全て nodes 配下。meta のみの日々の checkout は門を素通りさせる）
FILES="$(gh api "repos/$REPO/pulls/$PR/files" --paginate --jq '.[].filename')"
is_basis=no
if grep -qE '(^|/)AGENTS\.md$' <<<"$FILES"; then
  is_basis=yes
fi
if grep -qE '^docs/roadmap\.html$' <<<"$FILES"; then
  if gh api "repos/$REPO/contents/docs/roadmap.html?ref=$BASE_SHA" --jq '.content' 2>/dev/null | base64 -d > /tmp/base_roadmap.html \
     && gh api "repos/$REPO/contents/docs/roadmap.html?ref=$HEAD_SHA" --jq '.content' 2>/dev/null | base64 -d > /tmp/head_roadmap.html \
     && [ -s /tmp/base_roadmap.html ] && [ -s /tmp/head_roadmap.html ]; then
    if node .github/scripts/roadmap-basis-changed.mjs /tmp/base_roadmap.html /tmp/head_roadmap.html; then
      echo "roadmap.html は meta のみの変更 → 基準非対象"
    else
      is_basis=yes
    fi
  else
    echo "roadmap.html の base/head 取得に失敗 → 安全側で基準対象に倒す"
    is_basis=yes
  fi
fi
if [ "$is_basis" = no ]; then
  echo "基準変更なし。門は非対象。"
  set_status success "基準変更なし（門は非対象／handoff等のmeta更新はスルー）"
  exit 0
fi
echo "基準変更を検出。基準凍結の門を適用。"

# 2) 必須レビュアー（コメント/空行を除去）
mapfile -t REQUIRED < <(grep -vE '^\s*(#|$)' "$CONFIG" | tr -d ' \t\r')
if [ "${#REQUIRED[@]}" -eq 0 ] \
   || printf '%s\n' "${REQUIRED[@]}" | grep -qE '^REPLACE_WITH_'; then
  set_status failure "門番未設定: $CONFIG に必須レビュアーの実ログインを記入せよ"
  echo "required reviewers not configured (placeholders present)"; exit 1
fi

# 3) 各必須レビュアーの「現HEADでの最終判定」を求める。
#    COMMENT は無視し、最後の APPROVED / CHANGES_REQUESTED を有効な判定とする（stale尊重）。
objections=()   # CHANGES_REQUESTED（反証）
pending=()      # 判定なし
approved=()     # APPROVED
for r in "${REQUIRED[@]}"; do
  state="$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
    --jq "[ .[] | select(.commit_id==\"$HEAD_SHA\") | select(.user.login==\"$r\") \
            | select(.state==\"APPROVED\" or .state==\"CHANGES_REQUESTED\") | .state ] | last // \"NONE\"")"
  case "$state" in
    APPROVED)          approved+=("$r") ;;
    CHANGES_REQUESTED) objections+=("$r") ;;
    *)                 pending+=("$r") ;;
  esac
done
echo "承認:${approved[*]:-なし} / 反証:${objections[*]:-なし} / 待ち:${pending[*]:-なし}"

# 4) 判定：反証があれば STOP（Y）。全員承認で GO。
if [ "${#objections[@]}" -gt 0 ]; then
  set_status failure "反証あり(要対応): $(IFS=,; echo "${objections[*]}") — 直すか、マスターが理由付きで承認し直す"
  echo "objections stand: ${objections[*]}"; exit 1
fi
if [ "${#pending[@]}" -gt 0 ]; then
  set_status failure "承認待ち: $(IFS=,; echo "${pending[*]}")（現HEADへの承認のみ有効）"
  echo "pending approvals: ${pending[*]}"; exit 1
fi

set_status success "反証なし・必須承認そろい: $(IFS=,; echo "${approved[*]}")"
echo "gate passed"; exit 0
