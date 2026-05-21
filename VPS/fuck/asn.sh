#!/usr/bin/env bash

set -euo pipefail

output_file="ipcidr.txt"
asn_input=""

usage() {
    echo "用法:"
    echo "  $0 -a ASN1,ASN2,ASN3"
    echo
    echo "示例:"
    echo "  $0 -a 4134"
    echo "  $0 -a 4134,4837,9808"
    exit 1
}

while getopts ":a:o:h" opt; do
    case "$opt" in
        a)
            asn_input="$OPTARG"
            ;;
        o)
            output_file="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "未知参数: -$OPTARG"
            usage
            ;;
        :)
            echo "参数 -$OPTARG 需要传值"
            usage
            ;;
    esac
done

if [[ -z "$asn_input" ]]; then
    echo "错误: 必须使用 -a 指定 ASN"
    usage
fi

tmp_file=$(mktemp)

IFS=',' read -ra as_numbers <<< "$asn_input"

for asn in "${as_numbers[@]}"; do
    asn=$(echo "$asn" | xargs)

    [[ -z "$asn" ]] && continue

    echo "Fetching prefixes for AS${asn}..."

    url="https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${asn}"
    http_code=$(curl -s -w "%{http_code}" -o /tmp/asn_resp.json "$url")

    if [[ "$http_code" == "200" ]]; then
        jq -r '.data.prefixes[]?.prefix' /tmp/asn_resp.json \
            | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$' \
            >> "$tmp_file"
    else
        echo "Failed to fetch data for AS${asn}, HTTP Status: $http_code"
    fi
done

sort -u "$tmp_file" > "$output_file"
rm -f "$tmp_file" /tmp/asn_resp.json

echo "Done, saved to $output_file"