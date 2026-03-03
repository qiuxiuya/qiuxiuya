#!/usr/bin/env bash
set -euo pipefail

QBT_BASE_URL="https://example.com"                    # qBittorrent WebUI 地址（末尾不要 /）
QBT_USER="your_username"                              # WebUI 用户名；留空可跳过登录
QBT_PASS="your_password"                              # WebUI 密码；留空可跳过登录
FEEDS_JSON="$HOME/.config/qBittorrent/rss/feeds.json"     # feeds.json 文件路径
RULE_NAME="RSS_RULE"                                  # 要写入的 RSS 规则名
BLACKLIST_JSON='[
  "example-blacklist-keyword-1",
  "example-blacklist-keyword-2"
]'                                                     # 黑名单关键词（JSON 数组）

command -v jq >/dev/null 2>&1 || { echo "missing: jq"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "missing: curl"; exit 1; }
[[ -f "$FEEDS_JSON" ]] || { echo "not found: $FEEDS_JSON"; exit 1; }

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
    if [[ "$name" == *"$kw"* || "$url" == *"$kw"* ]]; then
      return 0
    fi
  done
  return 1
}

declare -A seen
final_urls=()

while IFS=$'\t' read -r name url; do
  if is_blacklisted "$name" "$url"; then
    continue
  fi
  if [[ -z "${seen[$url]+x}" ]]; then
    seen["$url"]=1
    final_urls+=("$url")
  fi
done < <(jq -r 'to_entries[] | select((.value.url // "") != "") | "\(.key)\t\(.value.url)"' "$FEEDS_JSON")

[[ "${#final_urls[@]}" -gt 0 ]] || { echo "no feeds after filtering"; exit 1; }

affected_feeds_json="$(printf '%s\n' "${final_urls[@]}" | jq -R . | jq -s .)"

rule_def="$(jq -n --argjson feeds "$affected_feeds_json" '
{
  enabled: true,
  affectedFeeds: $feeds,
  mustContain: "",
  mustNotContain: "",
  episodeFilter: "",
  ignoreDays: 0,
  priority: 0,
  smartFilter: false,
  useRegex: false,
  assignedCategory: "",
  savePath: "",
  torrentContentLayout: null,
  torrentParams: {
    category: "",
    download_limit: -1,
    download_path: "",
    inactive_seeding_time_limit: -2,
    operating_mode: "AutoManaged",
    ratio_limit: -2,
    save_path: "",
    seeding_time_limit: -2,
    skip_checking: false,
    tags: [""],
    upload_limit: -1,
    stopped: null,
    content_layout: null
  }
}
')"

curl_args=(-fsS -X POST "$QBT_BASE_URL/api/v2/rss/setRule")
$USE_LOGIN && curl_args+=(-b "$COOKIE_JAR")

curl "${curl_args[@]}" \
  --data-urlencode "ruleName=$RULE_NAME" \
  --data-urlencode "ruleDef=$rule_def" >/dev/null

echo "ok: rule=$RULE_NAME feeds=${#final_urls[@]}"
