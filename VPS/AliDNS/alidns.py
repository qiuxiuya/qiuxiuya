import os
from aliyunsdkcore.client import AcsClient
from aliyunsdkalidns.request.v20150109.AddDomainRecordRequest import AddDomainRecordRequest
from aliyunsdkalidns.request.v20150109.DeleteDomainRecordRequest import DeleteDomainRecordRequest
from aliyunsdkalidns.request.v20150109.DescribeDomainRecordsRequest import DescribeDomainRecordsRequest

# ================= 配置 =================
ACCESS_KEY_ID = "阿里云AccessKeyID"
ACCESS_KEY_SECRET = "阿里云AccessKeySecret"
DOMAIN = "example.com"
SUBDOMAIN_MAP = {
    "CM": "a",  # CM.txt -> a.example.com
    "CU": "b",
    "CT": "c",
}
IP_FILE_DIR = "."       # CM.txt CU.txt CT.txt 文件目录
RECORD_TYPE = "A"
# =====================================

client = AcsClient(ACCESS_KEY_ID, ACCESS_KEY_SECRET, "cn-hangzhou")

def get_existing_records(subdomain):
    request = DescribeDomainRecordsRequest()
    request.set_accept_format('json')
    request.set_DomainName(DOMAIN)
    response = client.do_action_with_exception(request)
    import json
    records = json.loads(response.decode())["DomainRecords"]["Record"]
    return [r for r in records if r["RR"] == subdomain and r["Type"] == RECORD_TYPE]

def add_record(subdomain, ip):
    request = AddDomainRecordRequest()
    request.set_accept_format('json')
    request.set_DomainName(DOMAIN)
    request.set_RR(subdomain)
    request.set_Type(RECORD_TYPE)
    request.set_Value(ip)
    client.do_action_with_exception(request)
    print(f"新增 {subdomain}.{DOMAIN} -> {ip}")

def delete_record(record_id, ip, subdomain):
    request = DeleteDomainRecordRequest()
    request.set_accept_format('json')
    request.set_RecordId(record_id)
    client.do_action_with_exception(request)
    print(f"删除 {subdomain}.{DOMAIN} 记录 {ip}")

def sync_subdomain(subdomain, current_ips):
    records = get_existing_records(subdomain)
    existing_ip_map = {r["Value"]: r["RecordId"] for r in records}

    if not current_ips:
        for ip, record_id in existing_ip_map.items():
            delete_record(record_id, ip, subdomain)
        return
    for ip in current_ips:
        if ip not in existing_ip_map:
            add_record(subdomain, ip)

    for ip, record_id in existing_ip_map.items():
        if ip not in current_ips:
            delete_record(record_id, ip, subdomain)

def get_ips_from_file(file_path):
    if not os.path.exists(file_path):
        return []
    with open(file_path, "r") as f:
        return [line.strip() for line in f if line.strip()]

def main():
    for carrier, subdomain in SUBDOMAIN_MAP.items():
        ip_file = os.path.join(IP_FILE_DIR, f"{carrier}.txt")
        current_ips = get_ips_from_file(ip_file)
        sync_subdomain(subdomain, current_ips)

if __name__ == "__main__":
    main()