#!/usr/bin/env bash
set -euo pipefail

QBT_BASE_URL="https://example.com"
QBT_USER="your_username"
QBT_PASS="your_password"
FEEDS_JSON="$HOME/.config/qBittorrent/rss/feeds.json"
RULES_JSON="$HOME/.config/qBittorrent/rss/download_rules.json"

# 规则映射：左边是匹配关键词，右边是 download_rules.json 里的规则名
# 同一个 feed 只被第一个匹配的规则收录
# DEFAULT_RULE：不匹配任何关键词时的兜底规则名，留空则丢弃
RULES='{
  "CR":  "CR",
  "MKV": "RSS"
}'
DEFAULT_RULE=""

BLACKLIST_JSON='[
  "example-blacklist-keyword-1",
  "example-blacklist-keyword-2"
]'

command -v jq  >/dev/null 2>&1 || { echo "missing: jq";   exit 1; }
command -v curl>/dev/null 2>&1 || { echo "missing: curl";  exit 1; }
[[ -f "$FEEDS_JSON"  ]] || { echo "not found: $FEEDS_JSON";  exit 1; }
[[ -f "$RULES_JSON"  ]] || { echo "not found: $RULES_JSON";  exit 1; }

COOKIE_JAR="$(mktemp -t qbt_cookie.XXXXXX)"
trap 'rm -f "$COOKIE_JAR"' EXIT

USE_LOGIN=true
if [[ -z "${QBT_USER:-}" || -z "${QBT_PASS:-}" || "$QBT_USER" == "NULL" || "$QBT_PASS" == "NULL" ]]; then
  USE_LOGIN=false
else
  resp="$(curl -sS -c "$COOKIE_JAR" -X POST "$QBT_BASE_URL/api/v2/auth/login" \
    --data-urlencode "username=$QBT_USER" \
    --data-urlencode "password=$QBT_PASS")"
  [[ "$resp" == *"Ok"* || "$resp" == *"ok"* ]] || { echo "login failed: $resp"; exit 1; }
fi

mapfile -t BLACKLIST_KEYWORDS < <(jq -r '.[]' <<< "$BLACKLIST_JSON")

is_blacklisted() {
  local name="$1" url="$2"
  for kw in "${BLACKLIST_KEYWORDS[@]}"; do
    [[ -n "$kw" ]] || continue
    [[ "$name" == *"$kw"* || "$url" == *"$kw"* ]] && return 0
  done
  return 1
}

mapfile -t RULE_KEYS   < <(jq -r 'keys_unsorted[]' <<< "$RULES")
mapfile -t RULE_VALUES < <(jq -r '[keys_unsorted[] as $k | .[$k]] | .[]' <<< "$RULES")

match_rule() {
  local name="$1" url="$2"
  for i in "${!RULE_KEYS[@]}"; do
    local kw="${RULE_KEYS[$i]}"
    [[ -n "$kw" ]] || continue
    if [[ "$name" == *"$kw"* || "$url" == *"$kw"* ]]; then
      echo "${RULE_VALUES[$i]}"
      return
    fi
  done
  echo "$DEFAULT_RULE"
}

declare -A seen
declare -A rule_feeds

while IFS=$'\t' read -r name url; do
  is_blacklisted "$name" "$url" && continue
  [[ -n "${seen[$url]+x}" ]] && continue
  seen["$url"]=1

  rule="$(match_rule "$name" "$url")"
  [[ -z "$rule" ]] && continue

  rule_feeds["$rule"]+="$url"$'\n'
done < <(jq -r 'to_entries[] | select((.value.url // "") != "") | "\(.key)\t\(.value.url)"' "$FEEDS_JSON")

[[ "${#rule_feeds[@]}" -gt 0 ]] || { echo "no feeds matched any rule"; exit 1; }

set_rule() {
  local rule_name="$1"
  local affected_feeds_json="$2"

  local rule_def
  rule_def="$(jq -n \
    --argjson template "$(jq --arg r "$rule_name" '.[$r]' "$RULES_JSON")" \
    --argjson feeds "$affected_feeds_json" \
    '$template
     | del(.lastMatch, .previouslyMatchedEpisodes)
     | .affectedFeeds = $feeds'
  )"

  local curl_args=(-fsS -X POST "$QBT_BASE_URL/api/v2/rss/setRule")
  $USE_LOGIN && curl_args+=(-b "$COOKIE_JAR")

  curl "${curl_args[@]}" \
    --data-urlencode "ruleName=$rule_name" \
    --data-urlencode "ruleDef=$rule_def" >/dev/null
}

total_feeds=0
for rule_name in "${!rule_feeds[@]}"; do
  if ! jq -e --arg r "$rule_name" 'has($r)' "$RULES_JSON" >/dev/null 2>&1; then
    echo "warn: rule '$rule_name' not found in $RULES_JSON, skipping"
    continue
  fi

  mapfile -t urls < <(printf '%s' "${rule_feeds[$rule_name]}" | grep -v '^$')
  feeds_json="$(printf '%s\n' "${urls[@]}" | jq -R . | jq -s .)"
  set_rule "$rule_name" "$feeds_json"
  echo "ok: rule=$rule_name feeds=${#urls[@]}"
  (( total_feeds += ${#urls[@]} ))
done

echo "done: rules=${#rule_feeds[@]} total_feeds=$total_feeds"
