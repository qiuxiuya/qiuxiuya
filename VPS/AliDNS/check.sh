#!/usr/bin/env bash
ip_files=("CT.txt" "CU.txt" "CM.txt")

rules='[
  {"region": "Shandong"},
  {"country": "China","file":"CU.txt","invert":true},
  {"region":"Guangdong","file":"CT.txt","invert":true}
]'

matches_rules() {
  local info="$1" rules="$2" file="$3"
  local n; n=$(echo "$rules" | jq 'length')
  for (( i=0; i<n; i++ )); do
    local rule
    rule=$(echo "$rules" | jq ".[$i]")
    local rule_file invert
    rule_file=$(echo "$rule" | jq -r '.file // empty')
    invert=$(echo "$rule" | jq -r '.invert // false')
    [[ -n "$rule_file" && "$rule_file" != "$file" ]] && continue
    local match
    match=$(jq -n \
      --argjson info "$info" \
      --argjson rule "$rule" \
      '[$rule|to_entries[]|select(.key != "file" and .key != "invert")|(.key) as $k|(.value) as $v|
        ($info[$k]//"") | ascii_downcase == ($v|ascii_downcase)
       ]|all')
    [[ "$invert" == "true" ]] && match=$( [[ "$match" == "true" ]] && echo "false" || echo "true" )
    [[ "$match" == "true" ]] && return 0
  done
  return 1
}

for file in "${ip_files[@]}"; do
  [[ -f "$file" ]] || continue
  mapfile -t ips < <(grep -v '^\s*#' "$file" | grep -v '^\s*$' | tr -d ' \t\r')
  (( ${#ips[@]} == 0 )) && continue
  tmpdir_work=$(mktemp -d)
  for ip in "${ips[@]}"; do
    result=$(curl -sf --max-time 10 "http://ip-api.com/json/${ip}?fields=status,country,regionName,city,query" \
      | jq '{ip:.query, country, region:.regionName, city}' \
      || echo '{"ip":"'"$ip"'"}')
    echo "$result" > "${tmpdir_work}/${ip}"
  done
  keep=()
  for ip in "${ips[@]}"; do
    info=$(cat "${tmpdir_work}/${ip}")
    if matches_rules "$info" "$rules" "$file"; then
      echo "[DROP] $file $ip $info"
    else
      echo "[KEEP] $file $ip $info"
      keep+=("$ip")
    fi
  done
  rm -rf "$tmpdir_work"
  ( IFS=$'\n'; echo "${keep[*]}" ) > "$file"
done
