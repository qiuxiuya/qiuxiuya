import requests
import ipaddress

def fetch_ip_prefixes(as_number):
    url = f"https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS{as_number}"
    response = requests.get(url)

    if response.status_code == 200:
        data = response.json()
        prefixes = [
            item["prefix"] for item in data.get("data", {}).get("prefixes", [])
            if is_ipv4(item["prefix"])
        ]
        return prefixes
    else:
        print(f"Failed to fetch data for AS{as_number}, HTTP Status: {response.status_code}")
        return []

def is_ipv4(prefix):
    try:
        ipaddress.IPv4Network(prefix)
        return True
    except ValueError:
        return False

def main():
    as_numbers = input("ASN(多个可用逗号分隔):").split(',')
    as_numbers = [asn.strip() for asn in as_numbers]

    all_ipcird_list = []

    for as_number in as_numbers:
        print(f"Fetching prefixes for AS{as_number}...")
        ipcird_list = fetch_ip_prefixes(as_number)
        all_ipcird_list.extend(ipcird_list)

    all_ipcird_list = sorted(set(all_ipcird_list))

    with open("ipcird.txt", "w") as file:
        for ipcird in all_ipcird_list:
            file.write(ipcird + "\n")

    print("Done")

if __name__ == "__main__":
    main()
