import argparse
import ipaddress
import json
import sys
from typing import Iterable, Union
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BGP_HE_ORIGINATED_URL = "https://bgp.he.net/super-lg/report/api/v1/prefixes/originated/{}"
BGP_HE_AS_PAGE_URL = "https://bgp.he.net/AS{}#_prefixes"
OUTPUT_FILE = "ipcidr.txt"
TIMEOUT = 20
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/137.0.0.0 Safari/537.36"
)
DEFAULT_ROUTES = {"0.0.0.0/0", "::/0"}
IPNetwork = Union[ipaddress.IPv4Network, ipaddress.IPv6Network]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="通过 ASN 从 bgp.he.net 获取 CIDR，默认保留更精细前缀并移除其父网段；使用 --all 输出 IPv4 + IPv6。"
    )
    parser.add_argument(
        "-a",
        "--asn",
        required=True,
        help="ASN 号，多个用逗号分隔，例如 13335,16509 或 AS13335,AS16509",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="输出 IPv4 + IPv6，默认仅输出 IPv4",
    )
    parser.add_argument(
        "-n",
        action="store_true",
        help="不对 CIDR 去重/精简，按原始前缀写入",
    )
    return parser.parse_args()


def normalize_asn_item(item: str) -> str:
    token = item.strip().upper()
    if not token:
        raise ValueError("ASN 列表中存在空值")
    if token.startswith("AS"):
        token = token[2:]
    if not token.isdigit() or int(token) <= 0:
        raise ValueError(f"无效 ASN: {item}")
    return str(int(token))


def parse_asns(raw_value: str) -> list[str]:
    return list(dict.fromkeys(normalize_asn_item(item) for item in raw_value.split(",")))


def fetch_prefixes(asn: str) -> list[str]:
    request = Request(
        BGP_HE_ORIGINATED_URL.format(asn),
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/json, text/plain, */*",
            "Referer": BGP_HE_AS_PAGE_URL.format(asn),
        },
    )

    try:
        with urlopen(request, timeout=TIMEOUT) as response:
            payload = json.load(response)
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"获取 AS{asn} 的 bgp.he.net 数据失败: {exc}") from exc

    prefixes = payload.get("prefixes") if isinstance(payload, dict) else None
    if not isinstance(prefixes, list):
        raise RuntimeError("bgp.he.net 未返回前缀列表")

    return [
        prefix
        for item in prefixes
        if isinstance(item, dict)
        and (prefix := str(item.get("Prefix", item.get("prefix", ""))).strip())
        and prefix not in DEFAULT_ROUTES
    ]


def normalize_prefixes(prefixes: Iterable[str], include_ipv6: bool) -> list[IPNetwork]:
    grouped_networks: dict[int, set[IPNetwork]] = {4: set(), 6: set()}

    for prefix in prefixes:
        try:
            network = ipaddress.ip_network(prefix, strict=False)
        except ValueError:
            continue

        if include_ipv6 or network.version == 4:
            grouped_networks[network.version].add(network)

    result: list[IPNetwork] = []
    for version in (4, 6):
        kept_networks: list[IPNetwork] = []

        for network in sorted(
            grouped_networks[version],
            key=lambda current: (-current.prefixlen, int(current.network_address)),
        ):
            if not any(existing.subnet_of(network) for existing in kept_networks):
                kept_networks.append(network)

        result.extend(
            sorted(
                kept_networks,
                key=lambda network: (int(network.network_address), network.prefixlen),
            )
        )

    return result


def filter_prefixes(prefixes: Iterable[str], include_ipv6: bool) -> list[str]:
    return [
        prefix
        for prefix in prefixes
        if _prefix_version(prefix) is not None
        and (include_ipv6 or _prefix_version(prefix) == 4)
    ]



def _prefix_version(prefix: str) -> int | None:
    try:
        return ipaddress.ip_network(prefix, strict=False).version
    except ValueError:
        return None


def write_output(lines: Iterable[str]) -> None:
    try:
        with open(OUTPUT_FILE, "w", encoding="utf-8") as file:
            file.writelines(f"{line}\n" for line in lines)
    except OSError as exc:
        raise RuntimeError(f"写入 {OUTPUT_FILE} 失败: {exc}") from exc


def main() -> int:
    args = parse_args()

    try:
        prefixes = [prefix for asn in parse_asns(args.asn) for prefix in fetch_prefixes(asn)]
        lines = (
            filter_prefixes(prefixes, include_ipv6=args.all)
            if args.n
            else [network.with_prefixlen for network in normalize_prefixes(prefixes, include_ipv6=args.all)]
        )
        write_output(lines)
    except (ValueError, RuntimeError) as exc:
        print(f"错误: {exc}", file=sys.stderr)
        return 1

    print(f"已写入 {OUTPUT_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
