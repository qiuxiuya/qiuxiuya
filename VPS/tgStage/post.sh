#!/bin/bash

# Telegram 配置
TELEGRAM_TOKEN="你的Botapi"
TELEGRAM_CHAT_ID="url推送的群组ID"
TELEGRAM_API="https://api.telegram.org/bot${TELEGRAM_TOKEN}"

#tgStage api配置
apiurl="http://localhost:8088/api"




send_message() {
    local text="$1"
    curl -s -X POST "${TELEGRAM_API}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${text}"
}
file_path=""

while getopts ":p:" opt; do
  case $opt in
    p)
      file_path="$OPTARG"
      ;;
    :)
      exit 1
      ;;
  esac
done

if [ -z "$file_path" ]; then
  read -e -p "请输入文件路径: " file_path
fi

if [ ! -f "$file_path" ]; then
  echo "文件不存在"
  exit 1
fi

file_name=$(basename "$file_path")
file_size=$(stat -c %s "$file_path")
human_size=$(numfmt --to=iec $file_size)
chunk_size=$((10*1024*1024)) 
temp_dir=$(mktemp -d)

upload_file() {
    local file="$1"
    local response=$(curl -s -X POST -F "image=@$file" "$apiurl")
    if echo "$response" | grep -q '"url"'; then
        echo "$response" | grep -o '"url":"[^"]*' | cut -d'"' -f4
    else
        echo "上传失败"
        exit 1
    fi
}

# 大文件处理
if [ "$file_size" -gt "$chunk_size" ]; then
    echo "切片ing: $file_name (大小: $human_size)"
    
    split -d -b "$chunk_size" "$file_path" "$temp_dir/blob"
    
    blobs=("$temp_dir"/blob*)
    blob_parts=()

    for blob in "${blobs[@]}"; do
        echo "正在上传: $blob"
        url=$(upload_file "$blob")
        blob_parts+=("$(echo "$url" | sed 's|.*/d/||')")
    done

    {
        echo "tgstate-blob"
        echo "$file_name"
        echo "size$file_size"
        printf "%s\n" "${blob_parts[@]}"
    } > "$temp_dir/fileAll.txt"

    final_url=$(upload_file "$temp_dir/fileAll.txt")
    
    message="${file_name}"$'\n'"${final_url}"$'\n'"${human_size}"
    send_message "$message"
    else
    echo "正在上传文件: $file_name"
    file_url=$(upload_file "$file_path")
    message="${file_name}"$'\n'"${file_url}"$'\n'"${human_size}"
    send_message "$message"
fi
rm -rf "$temp_dir"