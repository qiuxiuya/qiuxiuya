# -*- coding: utf-8 -*-
"""阿里云 ECS 流量保活脚本 — config.json 配置，根据 CDT 流量自动启停 ECS，Telegram 通知。"""

from aliyunsdkcore.client import AcsClient
from aliyunsdkcore.request import CommonRequest
from aliyunsdkecs.request.v20140526 import (StartInstancesRequest, StopInstancesRequest,
                                              DescribeInstancesRequest, DescribeRegionsRequest)
import json, os, sys, time, requests

DIR = os.path.dirname(os.path.abspath(__file__))
CFG = os.path.join(DIR, "config.json")
ST = os.path.join(DIR, "keep_state.json")


def _parse_single_account(a, ak, sk, rid_override=None, er_override=None):
    """解析单个账号配置，返回标准化 account dict，失败返回 None。
    all_ECS / all_region_id 从顶层 a 读取，全局统一。"""
    rid = rid_override if rid_override is not None else a.get("region_id")
    all_ecs = a.get("all_ECS", False)
    all_rid = a.get("all_region_id", False)

    if not all_ecs:
        er = er_override if er_override is not None else a.get("ECS_instance_id")
        if er is None or rid is None:
            print(f"警告: 账号 {ak[:8]}... 缺少 ECS_instance_id/region_id，已跳过")
            return None
        el = er if isinstance(er, list) else [er]
        rl = rid if isinstance(rid, list) else [rid]
        if len(el) != len(rl):
            if len(el) == 1:
                el *= len(rl)
            elif len(rl) == 1:
                rl *= len(el)
            else:
                print(f"警告: 账号 {ak[:8]}... ECS_instance_id/region_id 数量不匹配，已跳过")
                return None
        instances = list(zip(el, rl))
        rid_first = rl[0]
    else:
        instances = []
        rid_first = rid if rid else "cn-hongkong"

    return {
        "access_key_id": ak,
        "access_key_secret": sk,
        "region_id": rid_first,
        "_instances": instances,
        "all_ECS": all_ecs,
        "all_region_id": all_rid,
    }


def load_config():
    if not os.path.exists(CFG): sys.exit(1)
    with open(CFG, encoding="utf-8") as f:
        c = json.load(f)

    # 验证顶级必填字段（traffic + tg）
    for s, k in [("traffic", "stop_threshold_GB"), ("traffic", "notify_interval_GB"),
                 ("tg", "bot_token"), ("tg", "chat_id")]:
        if k not in c.get(s, {}): sys.exit(1)

    a = c.setdefault("aliyun", {})
    keys = a.get("key")

    if keys and isinstance(keys, list):
        # ── 多账号模式 ──
        accounts = []
        for i, k in enumerate(keys):
            ak = k.get("access_key_id")
            sk = k.get("access_key_secret")
            if not ak or not sk:
                print(f"警告: key[{i}] 缺少 access_key_id/access_key_secret，已跳过")
                continue
            acc = _parse_single_account(
                a, ak, sk,
                rid_override=k.get("region_id"),
                er_override=k.get("ECS_instance_id"),
            )
            if acc:
                accounts.append(acc)

        if not accounts:
            print("错误: 没有有效的账号配置")
            sys.exit(1)

        a["_accounts"] = accounts
        # 向后兼容：首账号填充到顶级字段
        a["access_key_id"] = accounts[0]["access_key_id"]
        a["access_key_secret"] = accounts[0]["access_key_secret"]
        a["region_id"] = accounts[0]["region_id"]
        a["_instances"] = accounts[0]["_instances"]
        a["all_ECS"] = accounts[0]["all_ECS"]
        a["all_region_id"] = accounts[0]["all_region_id"]
    else:
        # ── 单账号兼容模式 ──
        for s, k in [("aliyun", "access_key_id"), ("aliyun", "access_key_secret"),
                      ("aliyun", "region_id")]:
            if k not in c.get(s, {}): sys.exit(1)
        acc = _parse_single_account(a, a["access_key_id"], a["access_key_secret"])
        if acc is None:
            sys.exit(1)
        a["_accounts"] = [acc]
        a["all_ECS"] = acc["all_ECS"]
        a["all_region_id"] = acc["all_region_id"]
        a["_instances"] = acc["_instances"]
        a["region_id"] = acc["region_id"]

    c.setdefault("traffic", {})["notify_threshold_GB"] = c["traffic"].get("notify_threshold_GB", 0)
    c.setdefault("tg", {})["notify_log"] = c["tg"].get("notify_log", True)
    return c


def acs(ak, sk, rid):
    try: return AcsClient(ak, sk, rid)
    except: return None


def query_traffic(cli):
    req = CommonRequest()
    req.set_domain("cdt.aliyuncs.com"); req.set_version("2021-08-13")
    req.set_action_name("ListCdtInternetTraffic"); req.set_method("POST")
    try:
        d = json.loads(cli.do_action_with_exception(req).decode())
        return sum(x.get("Traffic", 0) for x in d.get("TrafficDetails", [])) / (1024 ** 3)
    except: return None


def get_targets(ak, sk, paired, rid, all_rid, all_ECS):
    if not all_ECS:
        return paired
    if all_rid:
        # all regions
        regions = []
        for r in ("cn-hongkong", "cn-shanghai", "cn-beijing"):
            c = acs(ak, sk, r)
            if c: break
        if c:
            try:
                resp = json.loads(c.do_action_with_exception(DescribeRegionsRequest.DescribeRegionsRequest()).decode())
                regions = [x["RegionId"] for x in resp.get("Regions", {}).get("Region", [])]
            except: pass
    else:
        regions = [rid]
    result = []
    for r in regions:
        c = acs(ak, sk, r)
        if not c: continue
        try:
            req = DescribeInstancesRequest.DescribeInstancesRequest()
            req.set_PageSize(100)
            resp = json.loads(c.do_action_with_exception(req).decode())
            for inst in resp.get("Instances", {}).get("Instance", []):
                result.append((inst["InstanceId"], r))
        except: pass
    return result


def ecs_act(ak, sk, iid, rid, do_start):
    """统一起停：查询状态，已在目标状态则跳过，否则执行"""
    c = acs(ak, sk, rid)
    if not c: return "客户端初始化失败"
    try:
        req = DescribeInstancesRequest.DescribeInstancesRequest()
        req.set_InstanceIds([iid])
        st = json.loads(c.do_action_with_exception(req).decode()).get("Instances", {}).get("Instance", [])
        st = st[0]["Status"] if st else None
    except: return "状态查询失败"
    if st is None: return "状态查询失败"
    skip = ("Running", "Starting", "Stopping") if do_start else ("Stopped", "Starting", "Stopping")
    if st in skip: return st
    try:
        if do_start:
            req = StartInstancesRequest.StartInstancesRequest()
            req.set_InstanceIds([iid])
            c.do_action_with_exception(req)
            return "Running (启动请求已发送)"
        else:
            req = StopInstancesRequest.StopInstancesRequest()
            req.set_InstanceIds([iid]); req.set_ForceStop(False)
            c.do_action_with_exception(req)
            return "Stopped (停止请求已发送)"
    except Exception as e:
        return f"{'启动' if do_start else '停止'}失败: {e}"


def tg_send(token, cid, msg):
    if not token or token == "1234567890:AAxxxxxxxxxxxxxxxxxxxxxxxxxx": return
    try: requests.post(f"https://api.telegram.org/bot{token}/sendMessage",
                       json={"chat_id": cid, "text": msg}, timeout=10)
    except: pass


def _run_one_account(acc, t, g):
    """对单个账号执行完整的流量查询 + 启停逻辑，返回 (total_GB, results_or_error_str)。"""
    ak, sk, rid = acc["access_key_id"], acc["access_key_secret"], acc["region_id"]

    tc = acs(ak, sk, rid)
    if not tc:
        return None, f"账号 {ak[:8]}... 客户端初始化失败"

    total = query_traffic(tc)
    if total is None:
        return None, f"账号 {ak[:8]}... 流量查询失败"

    targets = get_targets(ak, sk, acc["_instances"], rid,
                          acc.get("all_region_id", False), acc.get("all_ECS", False))
    if not targets:
        return total, f"账号 {ak[:8]}... 未找到任何可操作的 ECS 实例"

    do_start = total < t["stop_threshold_GB"]
    results = [(iid, rr, ecs_act(ak, sk, iid, rr, do_start)) for iid, rr in targets]
    return total, results


def main():
    c = load_config()
    a, t, g = c["aliyun"], c["traffic"], c["tg"]
    accounts = a.get("_accounts", [])

    # ── 流量通知（用首账号流量，CDT 流量通常按主账号计）──
    first_acc = accounts[0]
    tc = acs(first_acc["access_key_id"], first_acc["access_key_secret"], first_acc["region_id"])
    if tc:
        total_first = query_traffic(tc)
        if total_first is not None:
            state = json.load(open(ST, encoding="utf-8")) if os.path.exists(ST) else {"last_notified_traffic_gb": 0}
            ni, nt = t["notify_interval_GB"], t.get("notify_threshold_GB", 0)
            if ni > 0 and total_first >= nt:
                last = state.get("last_notified_traffic_gb", 0)
                if int((total_first - nt) // ni) > int((max(0, last - nt)) // ni):
                    msg = (f"当前总流量: {total_first:.2f} GB\n通知门槛: {nt} GB\n"
                           f"通知间隔: 每 {ni} GB\n时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
                    tg_send(g["bot_token"], g["chat_id"], msg)
                    state["last_notified_traffic_gb"] = total_first
                    with open(ST, "w", encoding="utf-8") as f:
                        json.dump(state, f, indent=2)

    # ── 遍历所有账号 ──
    ts = time.strftime('%Y-%m-%d %H:%M:%S')
    all_errs = []
    out_parts = [f"🖥️ ECS 保活报告\n时间: {ts}"]

    for idx, acc in enumerate(accounts):
        total_val, res = _run_one_account(acc, t, g)
        label = acc["access_key_id"][:8]
        if isinstance(res, str):
            # 错误信息
            out_parts.append(f"\n账号 {idx+1} ({label}...): ❌ {res}")
            all_errs.append((idx + 1, label, res))
        else:
            # 正常结果列表
            out_parts.append(f"\n账号 {idx+1} ({label}...) | 流量: {total_val:.2f} GB")
            for iid, rr, st in res:
                out_parts.append(f"  区域ID: {rr}  ECS ID: {iid}  → {st}")
                if "失败" in st or "异常" in st:
                    all_errs.append((idx + 1, label, f"区域ID: {rr}  ECS ID: {iid}  错误: {st}"))

    out = "\n".join(out_parts)
    print(out)

    if g.get("notify_log", True):
        tg_send(g["bot_token"], g["chat_id"], out)
    else:
        if all_errs:
            err_msg = f"⚠️ 实例状态异常:\n时间: {ts}"
            for idx, label, detail in all_errs:
                err_msg += f"\n账号 {idx} ({label}...): {detail}"
            tg_send(g["bot_token"], g["chat_id"], err_msg)


if __name__ == "__main__":
    main()
