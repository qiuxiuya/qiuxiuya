import re
import json
import os

def process_smartdns_file(file_path):
    # 读取文件内容
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 按大类分组
    groups = {}
    current_group = None
    
    lines = content.split('\n')
    for line in lines:
        # 检查是否是大类标题
        group_match = re.match(r'# ---------- > (.+)', line)
        if group_match:
            current_group = group_match.group(1)
            groups[current_group] = []
            continue
        
        # 检查是否是域名行
        nameserver_match = re.match(r'nameserver /([^/]+)/<replace with groupname>', line)
        if nameserver_match and current_group:
            domain = nameserver_match.group(1)
            groups[current_group].append(domain)
    
    # 为每个大类生成JSON文件
    for group_name, domains in groups.items():
        if domains:  # 只处理有域名的大类
            # 创建JSON结构
            json_data = {
                "version": 3,
                "rules": [
                    {
                        "domain_suffix": sorted(list(set(domains)))  # 去重并排序
                    }
                ]
            }
            
            # 生成文件名（处理特殊字符）
            safe_name = group_name.replace('/', '_').replace(' ', '_').replace('?', 'Unknown')
            file_name = f"{safe_name}.json"
            
            # 写入JSON文件
            with open(file_name, 'w', encoding='utf-8') as f:
                json.dump(json_data, f, indent=2, ensure_ascii=False)
            
            print(f"Generated {file_name} with {len(json_data['rules'][0]['domain_suffix'])} domains")
    
    # 生成总集文件 unlock.json
    all_domains = []
    for domains in groups.values():
        all_domains.extend(domains)
    
    if all_domains:
        # 去重并排序所有域名
        unique_domains = sorted(list(set(all_domains)))
        
        # 创建总集 JSON 结构
        unlock_data = {
            "version": 3,
            "rules": [
                {
                    "domain_suffix": unique_domains
                }
            ]
        }
        
        # 写入 unlock.json 文件
        with open('unlock.json', 'w', encoding='utf-8') as f:
            json.dump(unlock_data, f, indent=2, ensure_ascii=False)
        
        print(f"Generated unlock.json with {len(unique_domains)} total domains")
    
    print(f"\nTotal groups processed: {len([g for g in groups.values() if g])}")
    return groups

if __name__ == "__main__":
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # 在脚本目录中查找 stream.smartdns.list 文件
    input_file = os.path.join(script_dir, 'stream.smartdns.list')
    
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found!")
        print("Please make sure stream.smartdns.list is in the same directory as this script.")
        exit(1)
    
    groups = process_smartdns_file(input_file)
    
    # 打印统计信息
    print("\nGroup statistics:")
    for group_name, domains in groups.items():
        if domains:
            unique_domains = len(set(domains))
            print(f"{group_name}: {unique_domains} unique domains")
