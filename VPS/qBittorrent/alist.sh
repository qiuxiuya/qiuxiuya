#!/bin/bash

TOKEN="TGbot Token"           #Telegram Bot 令牌
chat_ID="用户ID"              #接收消息的用户/群组 ID
URL="https://api.telegram.org/bot${TOKEN}"

url="http://127.0.0.1:5244"   #openlist 地址
username="username"           #用户名
password="passwd"             #密码

PATH_MAPPING='[                #从 openlist 移动的路径映射（源目录 → 目标目录，可配置多组）
  {"from": "/disk/", "to": "/1/updating"},
  {"from": "/disk/1", "to": "/2/updating"}
]'

BLACKLIST_JSON='[              #黑名单列表（通过读取分类）
  "BT",
  "MKV"
]'

urlencode() {
    local raw="$1"
    echo -n "$raw" | jq -sRr @uri
}

name=""
filter=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n)
      name="$2"
      shift 2
      ;;
    -f)
      if [[ -n "$2" && "$2" != -* ]]; then
        filter="$2"
        shift 2
      else
        filter=""
        shift 1
      fi
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$name" ]; then
  exit 1
fi

is_blacklisted=false

if [ -n "$filter" ]; then
  if echo "$BLACKLIST_JSON" | jq -e --arg f "$filter" '
      any(.[]; $f | contains(.))
    ' > /dev/null; then
    is_blacklisted=true
  fi
fi

if [ "$is_blacklisted" = false ]; then
  response=$(curl -s -X POST "$url/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"$username\", \"password\": \"$password\"}")

  token=$(echo "$response" | jq -r '.data.token')

  while IFS=$'\t' read -r pathform pathto; do
    curl -s --location --request POST "$url/api/fs/copy" \
      --header "Authorization:$token" \
      --header "Content-Type: application/json" \
      --data-raw '{
        "src_dir": "'"$pathform"'",
        "dst_dir": "'"$pathto"'",
        "names": [
            "'"$name"'"
        ]
      }'
  done < <(echo "$PATH_MAPPING" | jq -r '.[] | "\(.from)\t\(.to)"')
fi

if [ "$is_blacklisted" = true ]; then
  ENCODED_NAME=$(urlencode "[x] $name")
else
  ENCODED_NAME=$(urlencode "$name")
fi
curl -s -o /dev/null -X POST "${URL}/sendMessage" \
  -d chat_id="${chat_ID}" \
  -d text="$ENCODED_NAME"