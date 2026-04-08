import os
import time
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_session():
    session = requests.Session()
    retries = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504]
    )
    adapter = HTTPAdapter(max_retries=retries)
    session.mount('http://', adapter)
    session.mount('https://', adapter)
    session.headers.update({'User-Agent': 'IP-Lookup/1.0'})
    return session

def batch_query(ips, session):
    url = 'http://ip-api.com/batch'
    payload = [{'query': ip, 'fields': 'country'} for ip in ips]
    try:
        resp = session.post(url, json=payload, timeout=15)
        if resp.status_code == 200:
            return resp.json()
        else:
            print(f"Batch request failed with status {resp.status_code}")
            return []
    except Exception as e:
        print(f"Batch request error: {e}")
        return []

def main():
    script_dir = os.path.dirname(os.path.realpath(__file__))
    result_dir = os.path.join(script_dir, 'result')
    if os.path.exists(result_dir):
        import shutil
        shutil.rmtree(result_dir)
    os.makedirs(result_dir, exist_ok=True)
    cidr_file = os.path.join(script_dir, 'ipcird.txt')
    if not os.path.exists(cidr_file):
        print(f"Error: {cidr_file} not found!")
        input("Press Enter to exit...")
        return

    with open(cidr_file, 'r') as f:
        cidrs = [line.strip() for line in f if line.strip()]

    total = len(cidrs)
    if total == 0:
        print("No CIDR entries found.")
        input("Press Enter to exit...")
        return

    session = create_session()
    batch_size = 100

    for i in range(0, total, batch_size):
        batch = cidrs[i:i+batch_size]
        ips = [cidr.split('/')[0] for cidr in batch]
        
        results = batch_query(ips, session)
        if not results:
            print(f"\nBatch failed, falling back to single queries...")
            for cidr in batch:
                ip = cidr.split('/')[0]
                try:
                    resp = session.get(
                        f'http://ip-api.com/json/{ip}?fields=country',
                        timeout=5
                    )
                    if resp.status_code == 200:
                        country = resp.json().get('country', '')
                        if country:
                            with open(os.path.join(result_dir, f'{country}.txt'), 'a') as out:
                                out.write(cidr + '\n')
                    time.sleep(1.5)
                except Exception as e:
                    print(f"Error querying {ip}: {e}")
                print(f"Progress: {i + batch.index(cidr) + 1}/{total}", end='\r')
        else:
            for cidr, data in zip(batch, results):
                country = data.get('country', '')
                if country:
                    with open(os.path.join(result_dir, f'{country}.txt'), 'a') as out:
                        out.write(cidr + '\n')
            print(f"Progress: {min(i+batch_size, total)}/{total}", end='\r')
            time.sleep(1)

    print("\nDone!")
    input("Press Enter to exit...")

if __name__ == '__main__':
    main()