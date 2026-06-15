#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CIDR_FILE="$SCRIPT_DIR/ipcidr.txt"
RESULT_DIR="$SCRIPT_DIR/result"
BATCH_SIZE=1000

# ipinfo配置
IPINFO_TOKEN=""
IPINFO_BATCH_API="https://api.ipinfo.io/batch/lite"

rm -rf "$RESULT_DIR"
mkdir -p "$RESULT_DIR"

if [[ ! -f "$CIDR_FILE" ]]; then
    echo "Missing file: $CIDR_FILE"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Missing dependency: jq"
    exit 1
fi

mapfile -t CIDRS < <(grep -v '^[[:space:]]*$' "$CIDR_FILE")
TOTAL=${#CIDRS[@]}

if [[ "$TOTAL" -eq 0 ]]; then
    echo "No CIDR entries found"
    exit 0
fi

for ((i=0; i<TOTAL; i+=BATCH_SIZE)); do
    batch=("${CIDRS[@]:i:BATCH_SIZE}")

    if [[ -z "$IPINFO_TOKEN" || "$IPINFO_TOKEN" == "你的ipinfo_token" ]]; then
        printf '%s\n' "${batch[@]}" >> "$RESULT_DIR/error.txt"
        echo -ne "Progress: $(( i + ${#batch[@]} ))/$TOTAL\r"
        sleep 1
        continue
    fi

    ips_file="$(mktemp)"
    payload_file="$(mktemp)"
    resp_file="$(mktemp)"

    printf '%s\n' "${batch[@]/%/*}" | awk -F'/' '{print $1}' > "$ips_file"
    jq -R -s -c 'split("\n") | map(select(length > 0))' "$ips_file" > "$payload_file"

    if ! curl -fsS -X POST "${IPINFO_BATCH_API}?token=${IPINFO_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$(cat "$payload_file")" \
        -o "$resp_file"; then
        printf '%s\n' "${batch[@]}" >> "$RESULT_DIR/error.txt"
        rm -f "$ips_file" "$payload_file" "$resp_file"
        echo -ne "Progress: $(( i + ${#batch[@]} ))/$TOTAL\r"
        sleep 1
        continue
    fi

    if ! jq -e 'type == "object"' "$resp_file" >/dev/null 2>&1; then
        printf '%s\n' "${batch[@]}" >> "$RESULT_DIR/error.txt"
        rm -f "$ips_file" "$payload_file" "$resp_file"
        echo -ne "Progress: $(( i + ${#batch[@]} ))/$TOTAL\r"
        sleep 1
        continue
    fi

    for ((j=0; j<${#batch[@]}; j++)); do
        ip="${batch[$j]%%/*}"
        country=$(jq -r --arg ip "$ip" '.[$ip].country_code // empty' "$resp_file")

        if [[ -n "$country" ]]; then
            echo "${batch[$j]}" >> "$RESULT_DIR/$country.txt"
        else
            echo "${batch[$j]}" >> "$RESULT_DIR/error.txt"
        fi
    done

    rm -f "$ips_file" "$payload_file" "$resp_file"

    echo -ne "Progress: $(( i + ${#batch[@]} ))/$TOTAL\r"
    sleep 1
done

echo

echo "Done!"
