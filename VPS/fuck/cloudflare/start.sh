#!/bin/bash

PORT="443,8443"
ASN_ARG=""
USE_PING=1

#cfst配置
URL="https://speed.wey.dpdns.org"  #测速用的url

#masscan配置
RATE=20000  #masscan rate
RETRIES=1  #masscan 重试次数

#telegram配置
TOKEN=""
CHAT_ID=""
API="https://api.telegram.org/bot${TOKEN}"

#ipinfo配置
IPINFO_TOKEN="" 
IPINFO_BATCH_API="https://api.ipinfo.io/batch/lite"

CIDR_FILE="ipcidr.txt"
SCAN_JSON="scan.json"
RESULT_FILE="result.txt"
CFST_TMP="cfst.tmp"
PING_TMP="ping.tmp"
PING_HOSTS_TMP="ping_hosts.tmp"

NORMALIZED_ARGS=()
for arg in "$@"; do
    case "$arg" in
        -np|--no-ping)
            NORMALIZED_ARGS+=("-N")
            ;;
        *)
            NORMALIZED_ARGS+=("$arg")
            ;;
    esac
done
set -- "${NORMALIZED_ARGS[@]}"

while getopts "p:a:t:Fc:u:N" opt; do
    case $opt in
        p) PORT="$OPTARG" ;;
        a) ASN_ARG="$OPTARG" ;;
        t) RATE="$OPTARG" ;;
        F) PORT="0-65535" ;;
        c) CFCOLO="$OPTARG" ;;
        u) URL="$OPTARG" ;;
        N) USE_PING=0 ;;
        *)
            echo "Usage: $0 [-p port] [-a asn] [-t rate] [-F] [-c cfcolo] [-u url] [-np]"
            exit 1
            ;;
    esac
done

send_file() {
    local file="$1"

    [[ -f "$file" ]] || return 0

    curl -s -X POST "${API}/sendDocument" \
        -F chat_id="${CHAT_ID}" \
        -F document=@"$file" >/dev/null
}

send_text() {
    local text="$1"

    curl -s -X POST "${API}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${text}" >/dev/null
}

run_cfst() {
    local json="$1"

    ./cfst -m "$json" -httping -dd -p 0 -o "$CFST_TMP" ${CFCOLO:+-cfcolo "$CFCOLO"} ${URL:+-url "$URL"}

    if [[ -f "$CFST_TMP" ]]; then
        tr -d '\r' < "$CFST_TMP" | awk -F',' '
            NR > 1 && $8 != "N/A" && $8 != "" {
                print $1, $2, $8
            }
        ' >> "$RESULT_FILE"
    fi

    rm -f "$CFST_TMP"
}

fix_appended_json() {
    local file="$1"

    sed ':a;N;$!ba; s/\]\s*\[/,/g' "$file" > "${file}.fix" && mv "${file}.fix" "$file"
}

collect_live_hosts() {
    local target="$1"

    rm -f "$PING_TMP" "$PING_HOSTS_TMP"

    masscan --ping "$target" \
        --rate "$RATE" \
        --retries "$RETRIES" \
        -oL "$PING_TMP" \
        --wait 0

    if [[ ! -s "$PING_TMP" ]]; then
        rm -f "$PING_TMP"
        return 1
    fi

    awk '$1 == "open" {print $4}' "$PING_TMP" | sort -u > "$PING_HOSTS_TMP"

    rm -f "$PING_TMP"

    [[ -s "$PING_HOSTS_TMP" ]]
}

sort_result_by_ip() {
    local file="$1"

    awk '
    NF >= 3 {
        split($1, a, ".")
        if (length(a) == 4) {
            printf "%03d.%03d.%03d.%03d\t%s\n", a[1], a[2], a[3], a[4], $0
        }
    }' "$file" | sort | cut -f2-
}

enrich_result_lite() {
    local file="$1"

    [[ -s "$file" ]] || return 0

    if ! command -v jq >/dev/null 2>&1; then
        sort_result_by_ip "$file" > "${file}.sorted" && mv "${file}.sorted" "$file"
        return 0
    fi

    if [[ -z "$IPINFO_TOKEN" || "$IPINFO_TOKEN" == "你的ipinfo_token" ]]; then
        sort_result_by_ip "$file" > "${file}.sorted" && mv "${file}.sorted" "$file"
        return 0
    fi

    local tmpdir
    tmpdir="$(mktemp -d)"

    sort_result_by_ip "$file" | awk '!seen[$0]++' > "$tmpdir/result.sorted"

    awk '
    NF >= 3 {
        print $1 "\t" $2 "\t" $3
    }' "$tmpdir/result.sorted" > "$tmpdir/result.tsv"

    awk -F'\t' '{print $1}' "$tmpdir/result.tsv" | sort -u > "$tmpdir/ips.txt"

    : > "$tmpdir/ipinfo.tsv"

    split -l 1000 "$tmpdir/ips.txt" "$tmpdir/ips."

    for chunk in "$tmpdir"/ips.*; do
        [[ -s "$chunk" ]] || continue

        local payload
        payload="$(jq -R -s -c 'split("\n") | map(select(length > 0))' "$chunk")"

        if ! curl -fsS -X POST "${IPINFO_BATCH_API}?token=${IPINFO_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$payload" \
            -o "$tmpdir/resp.json"; then
            continue
        fi

        jq -r '
            to_entries[]
            | select(.value | type == "object")
            | [
                .key,
                (.value.country_code // "-"),
                (
                    ((.value.asn // "-") | tostring)
                    +
                    "_"
                    +
                    (.value.as_name // "")
                )
              ]
            | @tsv
        ' "$tmpdir/resp.json" >> "$tmpdir/ipinfo.tsv"
    done

    awk -F'\t' '
    BEGIN {
        OFS = " "
    }
    NR == FNR {
        country[$1] = $2
        asinfo[$1] = $3
        next
    }
    {
        ip = $1
        cc = ((ip in country) ? country[ip] : "-")
        asn = ((ip in asinfo) ? asinfo[ip] : "-")
        print $1, $2, $3, "|", cc, asn
    }
    ' "$tmpdir/ipinfo.tsv" "$tmpdir/result.tsv" > "$file"

    rm -rf "$tmpdir"
}

echo "=== start ==="

[[ -n "$ASN_ARG" ]] && python3 asn.py -a "$ASN_ARG"

> "$RESULT_FILE"
rm -f "$SCAN_JSON" "$PING_TMP" "$PING_HOSTS_TMP"

TOTAL_CIDR=$(grep -cv '^[[:space:]]*$' "$CIDR_FILE")
CURRENT_CIDR=0

while IFS= read -r cidr || [[ -n "$cidr" ]]; do
    [[ -z "${cidr//[[:space:]]/}" ]] && continue

    CURRENT_CIDR=$((CURRENT_CIDR + 1))

    if [[ "$USE_PING" -eq 1 ]]; then
        echo "ping ${CURRENT_CIDR}/${TOTAL_CIDR}: ${cidr}"

        if ! collect_live_hosts "$cidr"; then
            echo "no alive host"
            echo
            continue
        fi

        ALIVE_COUNT=$(wc -l < "$PING_HOSTS_TMP")
        echo "scan ${CURRENT_CIDR}/${TOTAL_CIDR}: ${cidr} (alive: ${ALIVE_COUNT})"

        masscan -p"$PORT" -iL "$PING_HOSTS_TMP" \
            --rate "$RATE" \
            --retries "$RETRIES" \
            --banner \
            -oJ "$SCAN_JSON" \
            --append-output \
            --wait 0

        rm -f "$PING_HOSTS_TMP"
    else
        echo "masscan ${CURRENT_CIDR}/${TOTAL_CIDR}: ${cidr}"

        masscan -p"$PORT" "$cidr" \
            --rate "$RATE" \
            --retries "$RETRIES" \
            --banner \
            -oJ "$SCAN_JSON" \
            --append-output \
            --wait 0
    fi

    echo

done < "$CIDR_FILE"

if [[ -s "$SCAN_JSON" ]]; then
    fix_appended_json "$SCAN_JSON"
    run_cfst "$SCAN_JSON"
fi

if [[ -s "$RESULT_FILE" ]]; then
    enrich_result_lite "$RESULT_FILE"
    send_file "$RESULT_FILE"
else
    send_text "none"
fi

rm -f "$SCAN_JSON" "$RESULT_FILE" "$PING_TMP" "$PING_HOSTS_TMP" paused.conf