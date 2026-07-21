#!/usr/bin/env bash
# 基準凍結の門番（2AIレビュー＋マスター承認・運用B）。
# docs/roadmap.html / AGENTS.md 系（＝criteria/verify・規律）に触るPRについて、
# .github/basis-reviewers.txt に列挙した必須承認者（＝マスター）の APPROVED が
# 現HEAD(commit SHA)に対してそろっているかを判定し、
# その結果を commit status `basis-gate` として head SHA に記録する。
# ※ Claude/Codex の2意見を読んだ上でマスターが承認する運用。2意見の照合は人間の規律
#    に委ね、機械が必須とするのはマスター承認のみ（docs/basis-gate.md 参照）。
#
# branch protection で status context `basis-gate` を必須にして初めて機械強制になる。
# 承認は head SHA に紐付くものだけ有効＝中身を変えると旧承認は無効(stale)。
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN required}"
: "${REPO:?REPO required}"
: "${PR:?PR required}"
: "${HEAD_SHA:?HEAD_SHA required}"

CONTEXT="basis-gate"
CONFIG=".github/basis-reviewers.txt"

set_status() {
  local state="$1" desc="$2"
  # description は140字上限。長い場合は切る。
  desc="${desc:0:140}"
  gh api -X POST "repos/$REPO/statuses/$HEAD_SHA" \
    -f state="$state" -f context="$CONTEXT" -f description="$desc" >/dev/null
}

# 1) 基準ファイルに触れているか（触れていなければ門は非対象＝pass）
FILES="$(gh api "repos/$REPO/pulls/$PR/files" --paginate --jq '.[].filename')"
if ! grep -qE '(^|/)AGENTS\.md$|^docs/roadmap\.html$' <<<"$FILES"; then
  echo "基準ファイル未変更。門は非対象。"
  set_status success "基準変更なし（門は非対象）"
  exit 0
fi
echo "基準ファイル変更を検出。2AI承認ゲートを適用。"

# 2) 必須レビュアー（コメント/空行を除去）
mapfile -t REQUIRED < <(grep -vE '^\s*(#|$)' "$CONFIG" | tr -d ' \t\r')
if [ "${#REQUIRED[@]}" -eq 0 ] \
   || printf '%s\n' "${REQUIRED[@]}" | grep -qE '^REPLACE_WITH_'; then
  set_status failure "門番未設定: $CONFIG に必須2AIの実ログインを記入せよ"
  echo "required reviewers not configured (placeholders present)"; exit 1
fi

# 3) 現HEADに対する APPROVED レビューの承認者（stale尊重・重複排除）
APPROVERS="$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
  --jq ".[] | select(.state==\"APPROVED\") | select(.commit_id==\"$HEAD_SHA\") | .user.login" \
  | sort -u)"
echo "現HEAD承認者: ${APPROVERS//$'\n'/, }"

# 4) 必須が全員そろっているか
missing=()
for r in "${REQUIRED[@]}"; do
  grep -qxF "$r" <<<"$APPROVERS" || missing+=("$r")
done

if [ "${#missing[@]}" -eq 0 ]; then
  set_status success "2AI承認そろい: $(paste -sd, - <<<"$APPROVERS")"
  echo "gate passed"; exit 0
fi

set_status failure "承認待ち: $(IFS=,; echo "${missing[*]}")（現HEADへの承認のみ有効）"
echo "missing approvals: ${missing[*]}"; exit 1
