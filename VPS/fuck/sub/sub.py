import re
import requests
import json
import os

TOKEN = "7306762047:AAFu-ykDYHiPoTJlQSdK5Sqm7cJcK0dT7Ws"
CHAT_ID = "-1002267977332"

def send_telegram_message(message):
    url_push = f"https://api.telegram.org/bot{TOKEN}/sendMessage"
    data_push = {
        "chat_id": CHAT_ID,
        "text": message,
        "parse_mode": "Markdown"
    }
    try:
        response = requests.post(url_push, json=data_push, timeout=10)
        response.raise_for_status()
        if response.json().get("ok", False):
            print("Telegram 推送成功")
    except requests.exceptions.RequestException as e:
        print(f"Telegram 推送失败: {e}")

def extract_ip_port(file_path):
    pattern = r"Host: (\d+\.\d+\.\d+\.\d+).*Ports: (\d+)/open/tcp"
    with open(file_path, 'r') as file:
        content = file.read()
    matches = re.findall(pattern, content)
    return matches

def is_ip_port_in_succeed_file(ip, port):
    if not os.path.exists("succeed.txt"):
        return False

    with open("succeed.txt", "r") as file:
        content = file.read()
        return f"http://{ip}:{port}/" in content

def check_api_and_save(ip, port):
    url = f"http://{ip}:{port}/api/storage"
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            if is_ip_port_in_succeed_file(ip, port):
                print(f"{ip}:{port} 已存在")
                return

            data = response.json()
            subs = data.get("subs", [])
            names = [sub.get("name") for sub in subs if sub.get("name")]

            if names:
                message = f"url: http://{ip}:{port}\n"
                for name in names:
                    download_url = f"http://{ip}:{port}/download/{name}"
                    message += f"[{name}]({download_url})\n"

                send_telegram_message(message)

                with open("succeed.txt", "a") as succeed_file:
                    for name in names:
                        download_url = f"http://{ip}:{port}/download/{name}"
                        succeed_file.write(download_url + "\n")
                        print(f"Success: {download_url}")
            else:
                print(f"{ip}:{port} 无订阅")
        else:
            print(f"{ip}:{port} Def")
    except requests.RequestException as e:
        print(f"Error accessing {url}: {e}")
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON from {url}: {e}")

def main():
    ip_port_list = extract_ip_port("scan.txt")
    for ip, port in ip_port_list:
        check_api_and_save(ip, port)

if __name__ == "__main__":
    main()