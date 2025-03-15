import os
import requests
script_dir = os.path.dirname(os.path.realpath(__file__))
result_dir = os.path.join(script_dir, 'result')
if os.path.exists(result_dir):
    import shutil
    shutil.rmtree(result_dir)
os.makedirs(result_dir, exist_ok=True)
with open(os.path.join(script_dir, 'ipcird.txt'), 'r') as file:
    lines = file.readlines()

total_lines = len(lines)

for index, line in enumerate(lines, start=1):
    ip = line.strip().split('/')[0]
    url = f'http://ip-api.com/json/{ip}?fields=country'
    response = requests.get(url)
    if response.status_code == 200:
        country = response.json().get('country', '')
        if country:
            with open(os.path.join(result_dir, f'{country}.txt'), 'a') as result_file:
                result_file.write(line)
    
    print(f"Progress: {index}/{total_lines}", end='\r')

input("Press Enter to exit...")
