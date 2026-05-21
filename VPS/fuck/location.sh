#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CIDR_FILE="$SCRIPT_DIR/ipcidr.txt"
RESULT_DIR="$SCRIPT_DIR/result"
BATCH_SIZE=100

rm -rf "$RESULT_DIR"
mkdir -p "$RESULT_DIR"

mapfile -t CIDRS < <(grep -v '^[[:space:]]*$' "$CIDR_FILE")
TOTAL=${#CIDRS[@]}

for ((i=0; i<TOTAL; i+=BATCH_SIZE)); do
    batch=("${CIDRS[@]:i:BATCH_SIZE}")

    json="["
    for ((j=0; j<${#batch[@]}; j++)); do
        ip="${batch[$j]%%/*}"
        json+="{\"query\":\"$ip\",\"fields\":\"country\"}"
        [ $j -lt $((${#batch[@]} - 1)) ] && json+=","
    done
    json+="]"

    resp=$(curl -s "http://ip-api.com/batch" \
        -H "Content-Type: application/json" \
        -d "$json")

    if ! echo "$resp" | jq -e 'type == "array"' >/dev/null 2>&1; then
        printf '%s\n' "${batch[@]}" >> "$RESULT_DIR/error.txt"
        echo -ne "Progress: $(( i + ${#batch[@]} ))/$TOTAL\r"
        sleep 1
        continue
    fi

    for ((j=0; j<${#batch[@]}; j++)); do
        country=$(echo "$resp" | jq -r ".[$j].country // empty")
        if [ -n "$country" ]; then
            echo "${batch[$j]}" >> "$RESULT_DIR/$country.txt"
        else
            echo "${batch[$j]}" >> "$RESULT_DIR/error.txt"
        fi
    done

    echo -ne "Progress: $(( i + ${#batch[@]} ))/$TOTAL\r"
    sleep 1
done

echo
echo "Done!"