#!/usr/bin/python

import requests

data = requests.get("https://ip-ranges.amazonaws.com/ip-ranges.json")
prefixes = data.json()["prefixes"]
selected_prefixes = set()

regions = {"ap-east-1", "ap-northeast-1", "ap-northeast-2", "ap-northeast-3", "ap-southeast-1","cn-north-1","cn-northwest-1"}  
for prefix in prefixes:
    if prefix["region"] in regions and prefix["service"] in ("EC2", "S3"):
        selected_prefixes.add(prefix["ip_prefix"])

sorted_prefixes = sorted(selected_prefixes)

with open("ipcird.txt", "w") as file:
    file.write("\n".join(sorted_prefixes))

print(f"已保存 {len(sorted_prefixes)} 个 IP 前缀到 ipcird.txt")
