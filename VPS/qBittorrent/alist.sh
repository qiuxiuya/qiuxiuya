#!/bin/bash

TOKEN="Telegram BotToken"
chat_ID="Telegram Chat ID[带有-的]"
URL="https://api.telegram.org/bot${TOKEN}"

url="http://127.0.0.1:5244"
username="qiuxiuya"
password="ds8892527"
pathform="/local"
pathto="/ACG"

urlencode() {
    local raw="$1"
    echo -n "$raw" | jq -sRr @uri
}

while getopts "n:" opt; do
  case ${opt} in
    n)
      name="$OPTARG"
      ;;
    \?)
      echo "Usage: $0 -n name"
      exit 1
      ;;
  esac
done

if [ -z "$name" ]; then
  echo "Filename is required"
  exit 1
fi

response=$(curl -X POST "$url/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$username\", \"password\": \"$password\"}")

token=$(echo "$response" | jq -r '.data.token')

echo "Token: $token"

response=$(curl --location --request POST "$url/api/fs/copy" \
  --header "Authorization:$token" \
  --header "Content-Type: application/json" \
  --data-raw '{
    "src_dir": "'"$pathform"'",
    "dst_dir": "'"$pathto"'",
    "names": [
        "'"$name"'"
    ]
  }')

echo "Response: $response"

ENCODED_NAME=$(urlencode "$name")
curl -s -o /dev/null -X POST "${URL}/sendMessage" -d chat_id="${chat_ID}" -d text="$ENCODED_NAME"
