#!/bin/bash

TOKEN="TGbot Token"
chat_ID="用户ID"
URL="https://api.telegram.org/bot${TOKEN}"

url="http://127.0.0.1:5244" #openlist地址
username="username" #用户名
password="passwd"  #密码
pathform="/disk/bt"  #从openlist移动的起点目录
pathto="/ACG/updating"  #从openlist移动的终点目录

BLACKLIST_JSON='[
  "BT",
  "MKV"
]'  #黑名单列表（通过读取分类）

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
fi

if [ "$is_blacklisted" = true ]; then
  ENCODED_NAME=$(urlencode "[x] $name")
else
  ENCODED_NAME=$(urlencode "$name")
fi
curl -s -o /dev/null -X POST "${URL}/sendMessage" \
  -d chat_id="${chat_ID}" \
  -d text="$ENCODED_NAME"
