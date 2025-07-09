#!/bin/bash

TOKEN="8064716801:AAEQnBtVSX-vsdLi2DNmU9BniIqIYS8BgDc"
chat_ID="-1002709725329"
URL="https://api.telegram.org/bot${TOKEN}"

urlencode() {
    local raw="$1"
    echo -n "$raw" | jq -sRr @uri
}

NAME=""
DIRPATH=""

while getopts "n:p:" opt; do
  case $opt in
    n) NAME="$OPTARG" ;;
    p) DIRPATH="$OPTARG" ;;
    *) exit 1 ;;
  esac
done

[[ -z "$NAME" ]] && exit 1

FULL_PATH="${DIRPATH}${NAME}"

cp "$FULL_PATH" /root/updating/ -r

ENCODED_NAME=$(urlencode "$NAME")
curl -s -o /dev/null -X POST "${URL}/sendMessage" -d chat_id="${chat_ID}" -d text="$ENCODED_NAME"