import json
import os
import random
import time
import requests
import cloudscraper


def load_config(config_path='config.json'):
    """从 JSON 文件加载配置"""
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"配置文件 {config_path} 不存在")

    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)

    tg_config = config.get('tg', {})
    token = tg_config.get('token', '')
    chat_id_raw = tg_config.get('id', [])

    if isinstance(chat_id_raw, str):
        chat_ids = [chat_id_raw] if chat_id_raw else []
    elif isinstance(chat_id_raw, list):
        chat_ids = chat_id_raw
    else:
        chat_ids = []

    cookies_list = config.get('cookies', [])
    if not cookies_list:
        raise ValueError("配置文件中未找到 cookies 列表")

    return token, chat_ids, cookies_list


def build_cookie_string(cookie_dict):
    """将 Cookie 字典拼接成完整字符串"""
    parts = []
    for key, value in cookie_dict.items():
        if value:
            parts.append(f"{key}={value}")
    return '; '.join(parts)


def send_tg_notification(message, token, chat_ids):
    """向所有配置的 Telegram Chat ID 发送通知"""
    if not token or not chat_ids:
        return

    for chat_id in chat_ids:
        try:
            url = f"https://api.telegram.org/bot{token}/sendMessage"
            params = {'chat_id': chat_id, 'text': message}
            response = requests.get(url, params=params, timeout=10)
            if response.status_code != 200:
                print(f"TG通知失败: {response.status_code}")
        except Exception as e:
            print(f"TG通知异常: {e}")


def sign_in_with_cloudscraper():
    tg_token, tg_chat_ids, cookie_objects = load_config()

    if not cookie_objects:
        print("无账号配置")
        return

    url = 'https://www.nodeseek.com/api/attendance?random=true'
    scraper = cloudscraper.create_scraper(
        browser={'browser': 'chrome', 'platform': 'windows', 'desktop': True}
    )

    for idx, cookie_obj in enumerate(cookie_objects, 1):
        # 随机等待 2~30 分钟
        delay_sec = random.randint(2 * 60 , 30 * 60)
        print(f"账号 {idx} 等待 {delay_sec // 60} 分 {delay_sec % 60} 秒...")
        time.sleep(delay_sec)

        # 构建 Cookie 并解析为字典
        cookie_str = build_cookie_string(cookie_obj)
        cookie_dict = {}
        for item in cookie_str.split(';'):
            if '=' in item:
                k, v = item.split('=', 1)
                cookie_dict[k.strip()] = v.strip()

        headers = {
            'Accept': '*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Content-Length': '0',
            'Origin': 'https://www.nodeseek.com',
            'Referer': 'https://www.nodeseek.com/board',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
        }

        try:
            resp = scraper.post(url, headers=headers, cookies=cookie_dict, timeout=30)

            if resp.status_code == 200:
                print(f"账号 {idx} 签到成功")
            else:
                msg = f"账号 {idx} 签到失败，HTTP {resp.status_code}: {resp.text[:100]}"
                print(msg)
                send_tg_notification(msg, tg_token, tg_chat_ids)

        except Exception as e:
            msg = f"账号 {idx} 签到异常: {e}"
            print(msg)
            send_tg_notification(msg, tg_token, tg_chat_ids)


if __name__ == "__main__":
    try:
        sign_in_with_cloudscraper()
    except Exception as e:
        print(f"脚本错误: {e}")