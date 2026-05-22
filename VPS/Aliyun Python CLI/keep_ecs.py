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


def load_config():
    if not os.path.exists(CFG): sys.exit(1)
    with open(CFG, encoding="utf-8") as f:
        c = json.load(f)
    for s, k in [("aliyun","access_key_id"),("aliyun","access_key_secret"),("aliyun","region_id"),
                 ("traffic","stop_threshold_GB"),("traffic","notify_interval_GB"),
                 ("tg","bot_token"),("tg","chat_id")]:
        if k not in c.get(s, {}): sys.exit(1)
    a = c.setdefault("aliyun", {})
    a["all_ECS"] = a.get("all_ECS", False)
    a["all_region_id"] = a.get("all_region_id", False)
    if not a["all_ECS"]:
        er, rr = a.get("ECS_instance_id"), a.get("region_id")
        if er is None: sys.exit(1)
        el = er if isinstance(er, list) else [er]
        rl = rr if isinstance(rr, list) else [rr]
        if len(el) != len(rl):
            if len(el) == 1: el *= len(rl)
            elif len(rl) == 1: rl *= len(el)
            else: sys.exit(1)
        a["_instances"] = list(zip(el, rl))
        a["region_id"] = rl[0]
    else:
        a["_instances"] = []
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


def main():
    c = load_config()
    a, t, g = c["aliyun"], c["traffic"], c["tg"]
    ak, sk, rid = a["access_key_id"], a["access_key_secret"], a["region_id"]

    # traffic
    tc = acs(ak, sk, rid)
    if not tc: sys.exit(1)
    total = query_traffic(tc)
    if total is None: sys.exit(1)

    # state & notify
    state = json.load(open(ST, encoding="utf-8")) if os.path.exists(ST) else {"last_notified_traffic_gb": 0}
    ni, nt = t["notify_interval_GB"], t.get("notify_threshold_GB", 0)
    if ni > 0 and total >= nt:
        last = state.get("last_notified_traffic_gb", 0)
        if int((total - nt) // ni) > int((max(0, last - nt)) // ni):
            msg = (f"当前总流量: {total:.2f} GB\n通知门槛: {nt} GB\n"
                   f"通知间隔: 每 {ni} GB\n时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")
            tg_send(g["bot_token"], g["chat_id"], msg)
            state["last_notified_traffic_gb"] = total
            with open(ST, "w", encoding="utf-8") as f: json.dump(state, f, indent=2)

    # targets
    targets = get_targets(ak, sk, a["_instances"], rid, a.get("all_region_id", False), a.get("all_ECS", False))
    if not targets:
        tg_send(g["bot_token"], g["chat_id"], "未找到任何可操作的 ECS 实例，请检查配置。")
        sys.exit(1)

    do_start = total < t["stop_threshold_GB"]
    results = [(iid, rr, ecs_act(ak, sk, iid, rr, do_start)) for iid, rr in targets]

    ts = time.strftime('%Y-%m-%d %H:%M:%S')
    out = f"当前总流量: {total:.2f} GB\n时间: {ts}"
    for iid, rr, st in results:
        out += f"\n区域ID: {rr}\nECS ID: {iid}\n运行情况: {st}"
    print(out)
    if g.get("notify_log", True):
        tg_send(g["bot_token"], g["chat_id"], out)
    else:
        # 只在状态异常时通知（失败/错误信息）
        errs = [(iid, rr, st) for iid, rr, st in results if "失败" in st or "异常" in st]
        if errs:
            err_msg = f"⚠️ 实例状态异常:\n时间: {ts}"
            for iid, rr, st in errs:
                err_msg += f"\n区域ID: {rr}\nECS ID: {iid}\n错误: {st}"
            tg_send(g["bot_token"], g["chat_id"], err_msg)


if __name__ == "__main__":
    main()
