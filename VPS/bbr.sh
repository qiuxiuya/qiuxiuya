#!/usr/bin/env bash
# TCP 迷之调参 - 单文件交互式脚本

set -euo pipefail

line() {
  printf '%s\n' '═══════════════════════════════════════════════════'
}

header() {
  line
  echo "  TCP 迷之调参"
  echo "  交互式生成并应用 Linux 网络参数"
  line
}

ask_int() {
  local __var="$1"
  local prompt="$2"
  local def="$3"
  local min="$4"
  local max="$5"
  local input

  while true; do
    read -r -p "$prompt [$def]: " input
    input="${input:-$def}"
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= min && input <= max )); then
      printf -v "$__var" '%s' "$input"
      return
    fi
    echo "[错误] 请输入 ${min}-${max} 之间的整数"
  done
}

ask_yesno() {
  local __var="$1"
  local prompt="$2"
  local def="$3"
  local input

  while true; do
    read -r -p "$prompt [$def]: " input
    input="${input:-$def}"
    input="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
    case "$input" in
      y|yes)
        printf -v "$__var" '1'
        return
        ;;
      n|no)
        printf -v "$__var" '0'
        return
        ;;
      *)
        echo "[错误] 请输入 y 或 n"
        ;;
    esac
  done
}

choose_option() {
  local __var="$1"
  local title="$2"
  local def="$3"
  shift 3
  local opts=("$@")
  local i input pair

  echo "$title"
  for i in "${!opts[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${opts[$i]#*|}"
  done

  while true; do
    read -r -p "请选择 [$def]: " input
    input="${input:-$def}"
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#opts[@]} )); then
      pair="${opts[$((input - 1))]}"
      printf -v "$__var" '%s' "${pair%%|*}"
      return
    fi
    echo "[错误] 请输入 1-${#opts[@]} 之间的编号"
  done
}

version_name() {
  case "$1" in
    v1) echo "V1 - 基础版" ;;
    v2) echo "V2 - 大带宽版" ;;
    v25) echo "V2.5 - 低丢包版" ;;
    v3) echo "V3 - 内存感知版" ;;
    v4) echo "V4 - 爬升曲线版" ;;
    v5) echo "V5 - 综合优化版" ;;
    *) echo "$1" ;;
  esac
}

mem_name() {
  case "$1" in
    128) echo "128 MB" ;;
    256) echo "256 MB" ;;
    512) echo "512 MB" ;;
    768) echo "768 MB" ;;
    1024) echo "1 GB" ;;
    1536) echo "1.5 GB" ;;
    2048) echo "2 GB" ;;
    3072) echo "3 GB" ;;
    4096) echo "4 GB" ;;
    8192) echo "8 GB" ;;
    16384) echo "16 GB" ;;
    32768) echo "32 GB" ;;
    65536) echo "64 GB" ;;
    131072) echo "128 GB" ;;
    *) echo "$1 MB" ;;
  esac
}

algo_name() {
  case "$1" in
    bbr) echo "BBR" ;;
    cubic) echo "CUBIC" ;;
    *) echo "$1" ;;
  esac
}

qdisc_name() {
  case "$1" in
    fq) echo "FQ" ;;
    cake) echo "CAKE" ;;
    fq_pie) echo "FQ_PIE" ;;
    *) echo "$1" ;;
  esac
}

ramp_name() {
  case "$1" in
    0.20) echo "超平稳模式 (0.20)" ;;
    0.50) echo "平衡模式 (0.50)" ;;
    0.79) echo "高效模式 (0.79)" ;;
    0.95) echo "激进模式 (0.95)" ;;
    *) echo "$1" ;;
  esac
}

calc_notsent() {
  awk "BEGIN{v=int($1/2); print (v>524288)?524288:v}"
}

gen_v1() {
  local bdp rmem_max wmem_max
  bdp=$(awk "BEGIN{bw=($LOCAL_BW<$VPS_BW)?$LOCAL_BW:$VPS_BW; v=int(bw*1024*1024/8*$REAL_RTT/1000); print (v<16384)?16384:v}")
  rmem_max=$((bdp * 2))
  wmem_max=$bdp

  cat <<CONF
# TCP 迷之调参 V1
kernel.pid_max = 65535
kernel.panic = 10
kernel.sysrq = 0
kernel.core_pattern = /dev/null
kernel.printk = 4 4 1 7
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = 10
vm.dirty_ratio = 40
vm.dirty_background_ratio = 10
vm.panic_on_oom = 0
vm.overcommit_memory = 0
vm.min_free_kbytes = 65536
net.core.default_qdisc = fq
net.core.netdev_max_backlog = 16384
net.core.rmem_max = ${rmem_max}
net.core.wmem_max = ${wmem_max}
net.core.rmem_default = 87380
net.core.wmem_default = 65536
net.core.somaxconn = 32768
net.core.optmem_max = 81920
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_rmem = 4096 87380 ${rmem_max}
net.ipv4.tcp_wmem = 4096 65536 ${wmem_max}
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 0
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_orphans = 32768
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
}

gen_v2() {
  local sf eff bdp rmem_max wmem_max somaxconn netdev syn_backlog min_free optmem
  read -r sf eff bdp <<< "$(awk "BEGIN{sf=1.5*sqrt($LOCAL_BW/$VPS_BW); sf=(sf<1)?1:(sf>2)?2:sf; bw=(($LOCAL_BW*sf)<$VPS_BW)?($LOCAL_BW*sf):$VPS_BW; eff=int(bw*1024*1024/8); bdp=int(eff*$REAL_RTT/1000); bdp=(bdp<32768)?32768:bdp; print sf, eff, bdp}")"
  rmem_max=$((bdp * 4))
  wmem_max=$((bdp * 2))
  somaxconn=$(awk "BEGIN{v=int($eff/262144); print (v<512)?512:(v>4096)?4096:v}")
  netdev=$(awk "BEGIN{v=int($eff/131072); print (v<4000)?4000:(v>8000)?8000:v}")
  syn_backlog=$(awk "BEGIN{v=int($eff/65536); print (v<4096)?4096:(v>32768)?32768:v}")
  min_free=$(awk "BEGIN{v=int($eff/512); print (v<131072)?131072:(v>2097152)?2097152:v}")
  optmem=$(awk "BEGIN{v=int($bdp/2); print (v>131072)?131072:v}")

  cat <<CONF
# TCP 迷之调参 V2
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = 10
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = ${min_free}
net.core.default_qdisc = ${QDISC}
net.core.netdev_max_backlog = ${netdev}
net.core.rmem_max = ${rmem_max}
net.core.wmem_max = ${wmem_max}
net.core.rmem_default = 131072
net.core.wmem_default = 131072
net.core.somaxconn = ${somaxconn}
net.core.optmem_max = ${optmem}
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 65536
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 0
net.ipv4.tcp_rmem = 8192 131072 ${rmem_max}
net.ipv4.tcp_wmem = 8192 131072 ${wmem_max}
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = ${ALGO}
net.ipv4.tcp_notsent_lowat = 4096
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 3
net.ipv4.tcp_moderate_rcvbuf = 0
net.ipv4.tcp_no_metrics_save = 0
net.ipv4.tcp_max_syn_backlog = ${syn_backlog}
net.ipv4.tcp_max_orphans = 131072
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = 16384
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh1 = 2048
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
}

gen_v25() {
  local factor eff bdp rmem_min rmem_def rmem_max wmem_min wmem_def wmem_max somaxconn netdev syn_backlog min_free optmem adv_win notsent gc3 gc2 gc1 max_orphans latency_factor speed_factor queue_factor recv_factor send_factor

  if [ "$REAL_RTT" -gt 120 ]; then
    read -r latency_factor speed_factor eff bdp <<< "$(awk "BEGIN{lf=$REAL_RTT/40; lf=(lf<1)?1:(lf>4)?4:lf; sf=2*sqrt($LOCAL_BW/$VPS_BW)*lf; sf=(sf<1.5)?1.5:(sf>4)?4:sf; bw=(($LOCAL_BW*sf)<(1.8*$VPS_BW))?($LOCAL_BW*sf):(1.8*$VPS_BW); eff=int(bw*1024*1024/8); base=int(eff*$REAL_RTT/1000); base=(base>131072)?base:131072; alt=int(eff*$REAL_RTT/1200); bdp=(base>alt)?base:alt; print lf, sf, eff, bdp}")"
    recv_factor=$(awk "BEGIN{v=2*$latency_factor; print (v<6)?6:(v>12)?12:v}")
    send_factor=$(awk "BEGIN{v=1.5*$latency_factor; print (v<4)?4:(v>8)?8:v}")
    queue_factor=$(awk "BEGIN{v=$latency_factor; print (v<2)?2:(v>4)?4:v}")
    rmem_min=32768; rmem_def=262144; rmem_max=$(awk "BEGIN{print int($bdp*$recv_factor)}")
    wmem_min=16384; wmem_def=131072; wmem_max=$(awk "BEGIN{print int($bdp*$send_factor)}")
    somaxconn=$(awk "BEGIN{v=int($eff/32768*$queue_factor + 0.999999); print (v<1024)?1024:(v>16384)?16384:v}")
    netdev=$(awk "BEGIN{v=int($eff/8192*$queue_factor + 0.999999); print (v<16000)?16000:(v>32000)?32000:v}")
    syn_backlog=$(awk "BEGIN{v=int($eff/4096*$queue_factor + 0.999999); print (v<4096)?4096:(v>131072)?131072:v}")
    min_free=$(awk "BEGIN{v=int($eff/1024*0.8); print (v<65536)?65536:(v>524288)?524288:v}")
    optmem=$(awk "BEGIN{v=int($bdp/4); print (v>131072)?131072:v}")
    adv_win=$(awk "BEGIN{v=int(1.5*$latency_factor + 0.999999); print (v<2)?2:(v>8)?8:v}")
    notsent=$(calc_notsent "$bdp")
    gc3=4096; gc2=2048; gc1=1024; max_orphans=32768
  else
    read -r eff bdp <<< "$(awk "BEGIN{sf=1.5*sqrt($LOCAL_BW/$VPS_BW); sf=(sf<1)?1:(sf>2)?2:sf; bw=(($LOCAL_BW*sf)<$VPS_BW)?($LOCAL_BW*sf):$VPS_BW; eff=int(bw*1024*1024/8); bdp=int(eff*$REAL_RTT/1000 + 0.999999); bdp=(bdp<24576)?24576:bdp; print eff, bdp}")"
    rmem_min=8192; rmem_def=87380; rmem_max=$(awk "BEGIN{print int(3*$bdp)}")
    wmem_min=8192; wmem_def=65536; wmem_max=$(awk "BEGIN{print int(1.5*$bdp)}")
    somaxconn=$(awk "BEGIN{v=int($eff/262144 + 0.999999); print (v<256)?256:(v>2048)?2048:v}")
    netdev=$(awk "BEGIN{v=int($eff/131072 + 0.999999); print (v<2000)?2000:(v>4000)?4000:v}")
    syn_backlog=$(awk "BEGIN{v=int($eff/65536 + 0.999999); print (v<2048)?2048:(v>16384)?16384:v}")
    min_free=$(awk "BEGIN{v=int($eff/1024); print (v<65536)?65536:(v>1048576)?1048576:v}")
    optmem=$(awk "BEGIN{v=int($bdp/4); print (v>65536)?65536:v}")
    adv_win=2; notsent=4096; gc3=8192; gc2=4096; gc1=1024; max_orphans=65536
  fi

  cat <<CONF
# TCP 迷之调参 V2.5
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = 5
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = ${min_free}
net.core.default_qdisc = ${QDISC}
net.core.netdev_max_backlog = ${netdev}
net.core.rmem_max = ${rmem_max}
net.core.wmem_max = ${wmem_max}
net.core.rmem_default = 262144
net.core.wmem_default = 131072
net.core.somaxconn = ${somaxconn}
net.core.optmem_max = ${optmem}
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_rmem = ${rmem_min} ${rmem_def} ${rmem_max}
net.ipv4.tcp_wmem = ${wmem_min} ${wmem_def} ${wmem_max}
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = ${ALGO}
net.ipv4.tcp_notsent_lowat = ${notsent}
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${adv_win}
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_max_syn_backlog = ${syn_backlog}
net.ipv4.tcp_max_orphans = ${max_orphans}
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = ${gc3}
net.ipv4.neigh.default.gc_thresh2 = ${gc2}
net.ipv4.neigh.default.gc_thresh1 = ${gc1}
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
}

gen_v3() {
  local f eff bdp_base rmem_max wmem_max somaxconn netdev syn_backlog min_free optmem notsent adv_win gc3 gc2 gc1 max_orphans swappiness dirty_ratio dirty_bg fack no_metrics syn_retries rmem_def wmem_def qf h_mul v_mul somaxconn_max netdev_max syn_max

  if [ "$REAL_RTT" -gt 120 ]; then
    read -r f eff <<< "$(awk "BEGIN{f=$REAL_RTT/40; f=(f<1)?1:(f>5)?5:f; sf=2*sqrt($LOCAL_BW/$VPS_BW)*f; sf=(sf<1.5)?1.5:(sf>5)?5:sf; bw=(($LOCAL_BW*sf)<(2*$VPS_BW))?($LOCAL_BW*sf):(2*$VPS_BW); eff=int(bw*1024*1024/8); print f, eff}")"
    if [ "$MEM" -le 512 ]; then
      bdp_base=$(awk "BEGIN{v=int($eff*$REAL_RTT/1000); d=(v>131072)?v:131072; r=int($eff*$REAL_RTT/1200); print (d>r)?d:r}")
      h_mul=$(awk "BEGIN{v=1.6*$f; print (v<4.5)?4.5:(v>9)?9:v}")
      v_mul=$(awk "BEGIN{v=2.2*$f; print (v<6)?6:(v>12)?12:v}")
      min_free=$(awk "BEGIN{v=int($eff/1024*0.8); print (v<65536)?65536:(v>524288)?524288:v}")
      gc3=2048; gc2=1024; gc1=256; max_orphans=16384; somaxconn_max=20480; netdev_max=40000; syn_max=163840
    elif [ "$MEM" -le 1024 ]; then
      bdp_base=$(awk "BEGIN{v=int($eff*$REAL_RTT/1000); d=(v>262144)?v:262144; r=int($eff*$REAL_RTT/1000); print (d>r)?d:r}")
      h_mul=$(awk "BEGIN{v=2.4*$f; print (v<7)?7:(v>14)?14:v}")
      v_mul=$(awk "BEGIN{v=2.8*$f; print (v<9)?9:(v>18)?18:v}")
      min_free=$(awk "BEGIN{v=int($eff/1024*0.8); print (v<65536)?65536:(v>524288)?524288:v}")
      gc3=4096; gc2=2048; gc1=512; max_orphans=32768; somaxconn_max=40960; netdev_max=80000; syn_max=327680
    else
      bdp_base=$(awk "BEGIN{v=int($eff*$REAL_RTT/1000); d=(v>524288)?v:524288; r=int($eff*$REAL_RTT/800); print (d>r)?d:r}")
      h_mul=$(awk "BEGIN{v=2.8*$f; print (v<9)?9:(v>18)?18:v}")
      v_mul=$(awk "BEGIN{v=3.2*$f; print (v<11)?11:(v>22)?22:v}")
      min_free=$(awk "BEGIN{v=int($eff/1024); print (v<131072)?131072:(v>1048576)?1048576:v}")
      gc3=4096; gc2=2048; gc1=512; max_orphans=32768; somaxconn_max=40960; netdev_max=80000; syn_max=327680
    fi
    rmem_max=$(awk "BEGIN{print int($bdp_base*$v_mul)}")
    wmem_max=$(awk "BEGIN{print int($bdp_base*$h_mul)}")
    qf=$(awk "BEGIN{v=1.8*$f; print (v<3.5)?3.5:(v>7)?7:v}")
    somaxconn=$(awk "BEGIN{v=int($eff/32768*$qf); print (v<2560)?2560:(v>$somaxconn_max)?$somaxconn_max:v}")
    netdev=$(awk "BEGIN{v=int($eff/8192*$qf); print (v<40000)?40000:(v>$netdev_max)?$netdev_max:v}")
    syn_backlog=$(awk "BEGIN{v=int($eff/4096*$qf); print (v<20480)?20480:(v>$syn_max)?$syn_max:v}")
    optmem=$(awk "BEGIN{v=int($bdp_base/2); print (v<262144)?262144:v}")
    notsent=$(calc_notsent "$bdp_base")
    adv_win=$(awk "BEGIN{v=int(1.8*$f+0.5); print (v<2)?2:(v>8)?8:v}")
    swappiness=5; dirty_ratio=5; dirty_bg=2; fack=1; no_metrics=1; syn_retries=2; rmem_def=262144; wmem_def=262144
  else
    read -r eff bdp_base <<< "$(awk "BEGIN{sf=1.5*sqrt($LOCAL_BW/$VPS_BW); sf=(sf<1)?1:(sf>2)?2:sf; bw=(($LOCAL_BW*sf)<$VPS_BW)?($LOCAL_BW*sf):$VPS_BW; eff=int(bw*1024*1024/8); bdp=int(eff*$REAL_RTT/1000); bdp=(bdp<24576)?24576:bdp; print eff, bdp}")"
    if [ "$MEM" -le 256 ]; then
      rmem_max=$(awk "BEGIN{print int($bdp_base*2.5)}")
      wmem_max=$(awk "BEGIN{print int($bdp_base*1.2)}")
      min_free=$(awk "BEGIN{v=int($eff/1024*0.8); print (v<32768)?32768:(v>262144)?262144:v}")
      gc3=2048; gc2=1024; gc1=256
    elif [ "$MEM" -le 512 ]; then
      rmem_max=$(awk "BEGIN{print int($bdp_base*3)}")
      wmem_max=$(awk "BEGIN{print int($bdp_base*1.5)}")
      min_free=$(awk "BEGIN{v=int($eff/1024); print (v<65536)?65536:(v>524288)?524288:v}")
      gc3=2048; gc2=1024; gc1=256
    else
      rmem_max=$(awk "BEGIN{print int($bdp_base*4)}")
      wmem_max=$(awk "BEGIN{print int($bdp_base*2)}")
      min_free=$(awk "BEGIN{v=int($eff/1024*1.2); print (v<131072)?131072:(v>1048576)?1048576:v}")
      gc3=8192; gc2=4096; gc1=1024
    fi
    somaxconn=$(awk "BEGIN{v=int($eff/262144); print (v<256)?256:(v>2048)?2048:v}")
    netdev=$(awk "BEGIN{v=int($eff/131072); print (v<2000)?2000:(v>4000)?4000:v}")
    syn_backlog=$(awk "BEGIN{v=int($eff/65536); print (v<2048)?2048:(v>16384)?16384:v}")
    optmem=$(awk "BEGIN{v=int($bdp_base/4); print (v<65536)?65536:v}")
    notsent=4096; adv_win=2; max_orphans=65536; swappiness=10; dirty_ratio=10; dirty_bg=5; fack=0; no_metrics=0; syn_retries=3; rmem_def=87380; wmem_def=65536
  fi

  cat <<CONF
# TCP 迷之调参 V3
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = ${swappiness}
vm.dirty_ratio = ${dirty_ratio}
vm.dirty_background_ratio = ${dirty_bg}
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = ${min_free}
net.core.default_qdisc = ${QDISC}
net.core.netdev_max_backlog = ${netdev}
net.core.rmem_max = ${rmem_max}
net.core.wmem_max = ${wmem_max}
net.core.rmem_default = ${rmem_def}
net.core.wmem_default = ${wmem_def}
net.core.somaxconn = ${somaxconn}
net.core.optmem_max = ${optmem}
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = ${fack}
net.ipv4.tcp_rmem = 8192 ${rmem_def} ${rmem_max}
net.ipv4.tcp_wmem = 8192 ${wmem_def} ${wmem_max}
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = ${ALGO}
net.ipv4.tcp_notsent_lowat = ${notsent}
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${adv_win}
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = ${no_metrics}
net.ipv4.tcp_max_syn_backlog = ${syn_backlog}
net.ipv4.tcp_max_orphans = ${max_orphans}
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = ${syn_retries}
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = ${gc3}
net.ipv4.neigh.default.gc_thresh2 = ${gc2}
net.ipv4.neigh.default.gc_thresh1 = ${gc1}
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
}

gen_v4() {
  local f eff bdp_base rmem_max wmem_max somaxconn netdev syn_backlog min_free optmem notsent adv_win gc3 gc2 gc1 max_orphans swappiness dirty_ratio dirty_bg fack no_metrics syn_retries rmem_def wmem_def buf_f queue_f adv_f v_mul h_mul qf somaxconn_max netdev_max syn_max x fw

  if [ "$REAL_RTT" -gt 120 ]; then
    read -r f eff <<< "$(awk "BEGIN{f=$REAL_RTT/40; f=(f<1)?1:(f>5)?5:f; sf=2*sqrt($LOCAL_BW/$VPS_BW)*f; sf=(sf<1.5)?1.5:(sf>5)?5:sf; bw=(($LOCAL_BW*sf)<(2*$VPS_BW))?($LOCAL_BW*sf):(2*$VPS_BW); eff=int(bw*1024*1024/8); print f, eff}")"
    read -r buf_f queue_f adv_f <<< "$(awk "BEGIN{m=$RAMP*1.2; d=m*$f; buf=d*2.5; buf=(buf<8)?8:(buf>15)?15:buf; q=d*2; q=(q<4)?4:(q>8)?8:q; adv=d*1.6; adv=(adv<2)?2:(adv>10)?10:adv; print buf, q, adv}")"
    if [ "$MEM" -le 512 ]; then
      bdp_base=$(awk "BEGIN{v=int($eff*$REAL_RTT/1000); d=(v>131072)?v:131072; r=int($eff*$REAL_RTT/1200); print (d>r)?d:r}")
      v_mul=$(awk "BEGIN{v=2.2*$f; print (v<6)?6:(v>12)?12:v}")
      h_mul="$v_mul"; somaxconn_max=20480; netdev_max=40000; syn_max=163840
      min_free=$(awk "BEGIN{v=int($eff/1024*0.5); print (v<32768)?32768:(v>262144)?262144:v}")
    elif [ "$MEM" -le 1024 ]; then
      bdp_base=$(awk "BEGIN{v=int($eff*$REAL_RTT/1000); d=(v>262144)?v:262144; r=int($eff*$REAL_RTT/1000); print (d>r)?d:r}")
      v_mul=$(awk "BEGIN{v=2.8*$f; print (v<9)?9:(v>18)?18:v}")
      h_mul="$v_mul"; somaxconn_max=40960; netdev_max=80000; syn_max=327680
      min_free=$(awk "BEGIN{v=int($eff/1024*0.8); print (v<65536)?65536:(v>524288)?524288:v}")
    else
      bdp_base=$(awk "BEGIN{v=int($eff*$REAL_RTT/1000); d=(v>524288)?v:524288; r=int($eff*$REAL_RTT/800); print (d>r)?d:r}")
      v_mul=$(awk "BEGIN{v=3.2*$f; print (v<11)?11:(v>22)?22:v}")
      h_mul="$v_mul"; somaxconn_max=40960; netdev_max=80000; syn_max=327680
      min_free=$(awk "BEGIN{v=int($eff/1024); print (v<131072)?131072:(v>1048576)?1048576:v}")
    fi
    rmem_max=$(awk "BEGIN{print int($bdp_base*$v_mul*$buf_f)}")
    wmem_max=$(awk "BEGIN{print int($bdp_base*$h_mul*$buf_f)}")
    qf=$(awk "BEGIN{v=2.2*$f*$queue_f; print (v<4.5)?4.5:(v>9)?9:v}")
    somaxconn=$(awk "BEGIN{v=int($eff/32768*$qf); print (v<2560)?2560:(v>$somaxconn_max)?$somaxconn_max:v}")
    netdev=$(awk "BEGIN{v=int($eff/8192*$qf); print (v<40000)?40000:(v>$netdev_max)?$netdev_max:v}")
    syn_backlog=$(awk "BEGIN{v=int($eff/4096*$qf); print (v<20480)?20480:(v>$syn_max)?$syn_max:v}")
    optmem=$(awk "BEGIN{v=int($bdp_base/2); print (v<262144)?262144:v}")
    notsent=$(calc_notsent "$bdp_base")
    adv_win=$(awk "BEGIN{v=int($f*$adv_f+0.5); print (v<2)?2:(v>8)?8:v}")
    if [ "$MEM" -le 512 ]; then gc3=2048; gc2=1024; gc1=256; else gc3=4096; gc2=2048; gc1=512; fi
    if [ "$MEM" -le 256 ]; then max_orphans=16384; else max_orphans=32768; fi
    swappiness=5; dirty_ratio=5; dirty_bg=2; fack=1; no_metrics=1; syn_retries=2; rmem_def=262144; wmem_def=262144
  else
    read -r eff bdp_base <<< "$(awk "BEGIN{sf=1.5*sqrt($LOCAL_BW/$VPS_BW); sf=(sf<1)?1:(sf>2)?2:sf; bw=(($LOCAL_BW*sf)<$VPS_BW)?($LOCAL_BW*sf):$VPS_BW; eff=int(bw*1024*1024/8); bdp=int(eff*$REAL_RTT/1000); bdp=(bdp<24576)?24576:bdp; print eff, bdp}")"
    read -r buf_f queue_f adv_f <<< "$(awk "BEGIN{buf=$RAMP*1.5; buf=(buf<3)?3:(buf>4)?4:buf; q=$RAMP; q=(q<2)?2:(q>3)?3:q; adv=$RAMP; adv=(adv<1.5)?1.5:(adv>4)?4:adv; print buf, q, adv}")"
    if [ "$MEM" -le 256 ]; then
      x=2.5; fw=1.2; min_free=$(awk "BEGIN{v=int($eff/1024*0.8); print (v<32768)?32768:(v>262144)?262144:v}")
    elif [ "$MEM" -le 512 ]; then
      x=3; fw=1.5; min_free=$(awk "BEGIN{v=int($eff/1024); print (v<65536)?65536:(v>524288)?524288:v}")
    else
      x=4; fw=2; min_free=$(awk "BEGIN{v=int($eff/1024*1.2); print (v<131072)?131072:(v>1048576)?1048576:v}")
    fi
    rmem_max=$(awk "BEGIN{print int($bdp_base*$x*$buf_f)}")
    wmem_max=$(awk "BEGIN{print int($bdp_base*$fw*$buf_f)}")
    somaxconn=$(awk "BEGIN{v=int($eff/262144*$queue_f); print (v<256)?256:(v>2048)?2048:v}")
    netdev=$(awk "BEGIN{v=int($eff/131072*$queue_f); print (v<2000)?2000:(v>4000)?4000:v}")
    syn_backlog=$(awk "BEGIN{v=int($eff/65536*$queue_f); print (v<2048)?2048:(v>16384)?16384:v}")
    optmem=$(awk "BEGIN{v=int($bdp_base/4); print (v<65536)?65536:v}")
    notsent=4096; adv_win=$(awk "BEGIN{v=int($adv_f+0.5); print (v<2)?2:(v>8)?8:v}")
    gc3=8192; gc2=4096; gc1=1024; max_orphans=65536; swappiness=10; dirty_ratio=10; dirty_bg=5; fack=0; no_metrics=0; syn_retries=3; rmem_def=87380; wmem_def=65536
  fi

  cat <<CONF
# TCP 迷之调参 V4
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = ${swappiness}
vm.dirty_ratio = ${dirty_ratio}
vm.dirty_background_ratio = ${dirty_bg}
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = ${min_free}
net.core.default_qdisc = ${QDISC}
net.core.netdev_max_backlog = ${netdev}
net.core.rmem_max = ${rmem_max}
net.core.wmem_max = ${wmem_max}
net.core.rmem_default = ${rmem_def}
net.core.wmem_default = ${wmem_def}
net.core.somaxconn = ${somaxconn}
net.core.optmem_max = ${optmem}
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = ${fack}
net.ipv4.tcp_rmem = 8192 ${rmem_def} ${rmem_max}
net.ipv4.tcp_wmem = 8192 ${wmem_def} ${wmem_max}
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = ${ALGO}
net.ipv4.tcp_notsent_lowat = ${notsent}
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${adv_win}
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = ${no_metrics}
net.ipv4.tcp_max_syn_backlog = ${syn_backlog}
net.ipv4.tcp_max_orphans = ${max_orphans}
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = ${syn_retries}
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = ${gc3}
net.ipv4.neigh.default.gc_thresh2 = ${gc2}
net.ipv4.neigh.default.gc_thresh1 = ${gc1}
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
}

gen_v5() {
  local mem_eff
  mem_eff=$(awk "BEGIN{m=$MEM; print (m<64)?64:(m>32768)?32768:m}")

  if [ "$REAL_RTT" -gt 120 ]; then
    gen_v5_high "$mem_eff"
  else
    gen_v5_low "$mem_eff"
  fi
}

gen_v5_low() {
  local mem_eff="$1"
  local sf eff ratio ratio_factor bdp max_base cap_rate min_buf max_buf buffer_factor queue_factor adv_factor recv_mul send_mul
  local rmem_max wmem_max somaxconn netdev syn_backlog min_free optmem adv_win extreme_buf extreme_netdev extreme_syn tcp_mem_1 tcp_mem_2 tcp_mem_3

  read -r sf eff ratio ratio_factor bdp <<< "$(awk "BEGIN{sf=1.5*sqrt($LOCAL_BW/$VPS_BW); sf=(sf<1)?1:(sf>2)?2:sf; bw=(($LOCAL_BW*sf)<$VPS_BW)?($LOCAL_BW*sf):$VPS_BW; eff=int(bw*1024*1024/8); ratio=$LOCAL_BW/$VPS_BW; rf=1; if(ratio>1){rf=1/sqrt((ratio<100)?ratio:100); if(rf<0.3)rf=0.3}; bdp=int(eff*$REAL_RTT/1000 + 0.999999); if(bdp<24576)bdp=24576; print sf, eff, ratio, rf, bdp}")"

  cap_rate=$(awk "BEGIN{print ($mem_eff<=256)?0.1:0.125}")
  min_buf=$(awk "BEGIN{print ($mem_eff<=256)?4194304:8388608}")
  max_buf=$(awk "BEGIN{v=int(1.5*$RAMP*$ratio_factor*$bdp + 0.999999); cap=int(1024*$mem_eff*1024*$cap_rate); if(v>cap)v=cap; if(v<$min_buf)v=$min_buf; print v}")

  buffer_factor=$(awk "BEGIN{v=0.5+2.5*$RAMP; print (v<0.5)?0.5:(v>3)?3:v}")
  queue_factor=$(awk "BEGIN{v=0.3+1.7*$RAMP; print (v<0.3)?0.3:(v>2)?2:v}")
  adv_factor=$(awk "BEGIN{v=1+5*$RAMP; max=($mem_eff<=256)?3:(($mem_eff<=1024)?4:6); print (v<1)?1:(v>max)?max:v}")

  if [ "$mem_eff" -le 256 ]; then recv_mul=2.5; send_mul=1.2; tier=0.015; z=0.6
  elif [ "$mem_eff" -le 512 ]; then recv_mul=3; send_mul=1.5; tier=0.02; z=0.8
  elif [ "$mem_eff" -le 1024 ]; then recv_mul=4; send_mul=2; tier=0.025; z=1
  else recv_mul=4; send_mul=2; tier=0.03; z=1.2
  fi

  rmem_max=$(awk "BEGIN{v=int($bdp*$recv_mul*$buffer_factor); print (v>$max_buf)?$max_buf:v}")
  wmem_max=$(awk "BEGIN{v=int($bdp*$send_mul*$buffer_factor); print (v>$max_buf)?$max_buf:v}")
  qbase=$(awk "BEGIN{v=2*(($eff/65536>100)?$eff/65536:100); if(v>10000)v=10000; print int(v*$queue_factor + 0.999999)}")
  somaxconn=$(awk "BEGIN{v=int(0.2*$qbase*$z); print (v<256)?256:(v>2048)?2048:v}")
  netdev=$(awk "BEGIN{v=int(0.4*$qbase*$z); print (v<2000)?2000:(v>4000)?4000:v}")
  syn_backlog=$(awk "BEGIN{v=int(0.8*$qbase*$z); print (v<2048)?2048:(v>16384)?16384:v}")
  min_free=$(awk "BEGIN{v=int(1024*$mem_eff*$tier)+int(0.5*int($eff/1024 + 0.999999)); print (v<32768)?32768:(v>1048576)?1048576:v}")
  optmem=$(awk "BEGIN{v=int($bdp/4); print (v>65536)?65536:v}")
  adv_win=$(awk "BEGIN{v=int($adv_factor + 0.999999); print (v<2)?2:v}")

  if [ "$EXTREME" -eq 1 ]; then
    extreme_buf=$(awk "BEGIN{v=$eff*$REAL_RTT/1000*((8<(4+$mem_eff/2048))?8:(4+$mem_eff/2048)); cap=1024*$mem_eff*122.88; if(v>cap)v=cap; if(v<2097152)v=2097152; print int(v)}")
    max_netdev=$(awk "BEGIN{v=4*$mem_eff; print (v>16384)?16384:v}")
    k=$(awk "BEGIN{v=$eff/1048576; print (v>10000)?10000:v}")
    extreme_netdev=$(awk "BEGIN{v=4000+$k; print (v>$max_netdev)?$max_netdev:int(v)}")
    extreme_syn=$(awk "BEGIN{v=2048+$k/2; cap=$max_netdev/2; print (v>cap)?cap:int(v)}")
    tcp_mem_1=$((384 * mem_eff)); tcp_mem_2=$((512 * mem_eff)); tcp_mem_3=$((768 * mem_eff))
    cat <<CONF
# TCP 迷之调参 V5
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
kernel.sched_min_granularity_ns = 3000000
vm.swappiness = 1
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = $(awk "BEGIN{v=32*$mem_eff; print (v<131072)?131072:v}")
vm.vfs_cache_pressure = 100
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
net.core.default_qdisc = fq
net.core.netdev_max_backlog = ${extreme_netdev}
net.core.rmem_max = $((2 * extreme_buf))
net.core.wmem_max = ${extreme_buf}
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.somaxconn = 16384
net.core.optmem_max = $(awk "BEGIN{v=80*$mem_eff; print (v>81920)?81920:v}")
net.core.busy_read = 50
net.core.busy_poll = 50
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_rmem = 32768 262144 $((2 * extreme_buf))
net.ipv4.tcp_wmem = 32768 262144 ${extreme_buf}
net.ipv4.tcp_mem = ${tcp_mem_1} ${tcp_mem_2} ${tcp_mem_3}
net.ipv4.tcp_mtu_probing = 2
net.ipv4.tcp_congestion_control = ${ALGO}
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${adv_win}
net.ipv4.tcp_moderate_rcvbuf = 0
net.ipv4.tcp_no_metrics_save = 0
net.ipv4.tcp_max_syn_backlog = ${extreme_syn}
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.ip_forward = 0
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
    return
  fi

  cat <<CONF
# TCP 迷之调参 V5
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = ${min_free}
vm.vfs_cache_pressure = 100
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
net.core.default_qdisc = ${QDISC}
net.core.netdev_max_backlog = ${netdev}
net.core.rmem_max = ${max_buf}
net.core.wmem_max = ${max_buf}
net.core.rmem_default = 87380
net.core.wmem_default = 65536
net.core.somaxconn = ${somaxconn}
net.core.optmem_max = ${optmem}
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 0
net.ipv4.tcp_rmem = 8192 87380 ${rmem_max}
net.ipv4.tcp_wmem = 8192 65536 ${wmem_max}
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = ${ALGO}
net.ipv4.tcp_notsent_lowat = 4096
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${adv_win}
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 0
net.ipv4.tcp_max_syn_backlog = ${syn_backlog}
net.ipv4.tcp_max_orphans = 65536
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
}

gen_v5_high() {
  local mem_eff="$1"
  local f sf eff bdp base_bdp ratio ratio_n max_buf buffer_factor queue_factor adv_factor recv_mul send_mul rmem_max wmem_max j z somaxconn netdev syn_backlog min_free optmem notsent adv_win gc3 gc2 gc1 max_orphans extreme_buf max_netdev k extreme_netdev extreme_syn tcp_mem_1 tcp_mem_2 tcp_mem_3

  read -r f sf eff bdp <<< "$(awk "BEGIN{f=$REAL_RTT/40; f=(f<1)?1:(f>5)?5:f; sf=2*sqrt($LOCAL_BW/$VPS_BW)*f; sf=(sf<1.5)?1.5:(sf>5)?5:sf; bw=(($LOCAL_BW*sf)<(2*$VPS_BW))?($LOCAL_BW*sf):(2*$VPS_BW); eff=int(bw*1024*1024/8); bdp=int(eff*$REAL_RTT/1000 + 0.999999); print f, sf, eff, bdp}")"
  ratio=$(awk "BEGIN{print $LOCAL_BW/$VPS_BW}")
  ratio_n=$(awk "BEGIN{r=$ratio; if(r>100)n=0.06; else if(r>50)n=0.12; else if(r>20)n=0.2; else if(r>10)n=0.3; else if(r>5)n=0.5; else if(r>2)n=0.7; else n=1; print n}")

  if [ "$mem_eff" -le 512 ]; then
    base_bdp=$(awk "BEGIN{d=($bdp>131072)?$bdp:131072; alt=int($eff*$REAL_RTT/1200); print (d>alt)?d:alt}")
    recv_mul=$(awk "BEGIN{v=1.5*$f; print (v<3)?3:(v>6)?6:v}")
    send_mul="$recv_mul"; z=0.8; gc3=2048; gc2=1024; gc1=256; max_orphans=16384; qmax_s=8192; qmax_n=16384; qmax_syn=32768
  elif [ "$mem_eff" -le 1024 ]; then
    base_bdp=$(awk "BEGIN{d=($bdp>262144)?$bdp:262144; print d}")
    recv_mul=$(awk "BEGIN{v=1.8*$f; print (v<4)?4:(v>8)?8:v}")
    send_mul="$recv_mul"; z=1; gc3=4096; gc2=2048; gc1=512; max_orphans=32768; qmax_s=16384; qmax_n=32768; qmax_syn=65536
  else
    base_bdp=$(awk "BEGIN{d=($bdp>524288)?$bdp:524288; alt=int($eff*$REAL_RTT/800); print (d>alt)?d:alt}")
    recv_mul=$(awk "BEGIN{v=2*$f; print (v<5)?5:(v>10)?10:v}")
    send_mul="$recv_mul"; z=$(awk "BEGIN{print ($mem_eff<=2048)?1.3:1.5}"); gc3=4096; gc2=2048; gc1=512; max_orphans=32768; qmax_s=16384; qmax_n=32768; qmax_syn=65536
  fi

  buffer_factor=$(awk "BEGIN{v=1+7*$RAMP; print (v<1)?1:(v>8)?8:v}")
  queue_factor=$(awk "BEGIN{v=0.8+3.2*$RAMP; print (v<0.8)?0.8:(v>4)?4:v}")
  adv_factor=$(awk "BEGIN{v=2+8*$RAMP; print (v<2)?2:(v>16)?16:v}")
  max_buf=$(awk "BEGIN{v=int(2*$RAMP*$ratio_n*$bdp); cap=int(1024*$mem_eff*1024*0.125); if(v>cap)v=cap; if($REAL_RTT>500 && v<int(0.5*$bdp))v=int(0.5*$bdp); print v}")
  rmem_max=$(awk "BEGIN{v=int($base_bdp*$recv_mul*$buffer_factor); print (v>$max_buf)?$max_buf:v}")
  wmem_max=$(awk "BEGIN{v=int($base_bdp*$send_mul*$buffer_factor); print (v>$max_buf)?$max_buf:v}")
  j=$(awk "BEGIN{v=int((3*(($eff/131072>50)?$eff/131072:50))*$queue_factor + 0.999999); print (v>20000)?20000:v}")
  somaxconn=$(awk "BEGIN{v=int(0.15*$j*$z); print (v<2560)?2560:(v>$qmax_s)?$qmax_s:v}")
  netdev=$(awk "BEGIN{v=int(0.3*$j*$z); print (v<8192)?8192:(v>$qmax_n)?$qmax_n:v}")
  syn_backlog=$(awk "BEGIN{v=int(0.6*$j*$z); print (v<8192)?8192:(v>$qmax_syn)?$qmax_syn:v}")
  min_free=$(awk "BEGIN{tier=($mem_eff<=512)?0.02:(($mem_eff<=1024)?0.025:(($mem_eff<=2048)?0.03:0.035)); v=int(1024*$mem_eff*tier)+int(0.6*int($eff/1024 + 0.999999)); print (v<65536)?65536:(v>1048576)?1048576:v}")
  optmem=$(awk "BEGIN{v=int($base_bdp/2); print (v>262144)?262144:v}")
  notsent=$(calc_notsent "$base_bdp")
  adv_win=$(awk "BEGIN{v=int($f*$adv_factor + 0.999999); print (v<2)?2:v}")

  if [ "$EXTREME" -eq 1 ]; then
    extreme_buf=$(awk "BEGIN{v=$eff*$REAL_RTT/1000*((12<(6+$mem_eff/1024))?12:(6+$mem_eff/1024)); cap=1024*$mem_eff*153.6; if(v>cap)v=cap; if(v<4194304)v=4194304; print int(v)}")
    max_netdev=$(awk "BEGIN{v=6*$mem_eff; print (v>24576)?24576:v}")
    k=$(awk "BEGIN{v=$eff/1048576; if(v>15000)v=15000; kk=$REAL_RTT/100; if(kk>5)kk=5; print v, kk}")
    q=${k% *}; kk=${k#* }
    extreme_netdev=$(awk "BEGIN{v=6000+$q*$kk; print (v>$max_netdev)?$max_netdev:int(v)}")
    extreme_syn=$(awk "BEGIN{v=3000+$q*$kk/2; cap=$max_netdev/2; print (v>cap)?cap:int(v)}")
    tcp_mem_1=$((512 * mem_eff)); tcp_mem_2=$((768 * mem_eff)); tcp_mem_3=$((1024 * mem_eff))
    cat <<CONF
# TCP 迷之调参 V5
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = 1
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = $(awk "BEGIN{v=64*$mem_eff; print (v<262144)?262144:v}")
vm.vfs_cache_pressure = 100
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
net.core.default_qdisc = fq
net.core.netdev_max_backlog = ${extreme_netdev}
net.core.rmem_max = $((2 * extreme_buf))
net.core.wmem_max = ${extreme_buf}
net.core.rmem_default = 524288
net.core.wmem_default = 524288
net.core.somaxconn = 32768
net.core.optmem_max = $(awk "BEGIN{v=160*$mem_eff; print (v>163840)?163840:v}")
net.core.busy_read = 0
net.core.busy_poll = 0
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_rmem = 65536 524288 $((2 * extreme_buf))
net.ipv4.tcp_wmem = 65536 524288 ${extreme_buf}
net.ipv4.tcp_mem = ${tcp_mem_1} ${tcp_mem_2} ${tcp_mem_3}
net.ipv4.tcp_mtu_probing = 2
net.ipv4.tcp_congestion_control = ${ALGO}
net.ipv4.tcp_notsent_lowat = 32768
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${adv_win}
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_max_syn_backlog = ${extreme_syn}
net.ipv4.tcp_max_orphans = ${max_orphans}
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.ip_forward = 0
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = ${gc3}
net.ipv4.neigh.default.gc_thresh2 = ${gc2}
net.ipv4.neigh.default.gc_thresh1 = ${gc1}
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
    return
  fi

  cat <<CONF
# TCP 迷之调参 V5
kernel.pid_max = 65535
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = 5
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = ${min_free}
vm.vfs_cache_pressure = 100
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
net.core.default_qdisc = ${QDISC}
net.core.netdev_max_backlog = ${netdev}
net.core.rmem_max = ${max_buf}
net.core.wmem_max = ${max_buf}
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.somaxconn = ${somaxconn}
net.core.optmem_max = ${optmem}
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_rmem = 32768 262144 ${rmem_max}
net.ipv4.tcp_wmem = 32768 262144 ${wmem_max}
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = ${ALGO}
net.ipv4.tcp_notsent_lowat = ${notsent}
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${adv_win}
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_max_syn_backlog = ${syn_backlog}
net.ipv4.tcp_max_orphans = ${max_orphans}
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = ${gc3}
net.ipv4.neigh.default.gc_thresh2 = ${gc2}
net.ipv4.neigh.default.gc_thresh1 = ${gc1}
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1
CONF
}

generate_config() {
  case "$VERSION" in
    v1) gen_v1 ;;
    v2) gen_v2 ;;
    v25) gen_v25 ;;
    v3) gen_v3 ;;
    v4) gen_v4 ;;
    v5) gen_v5 ;;
    *) echo "[错误] 未知版本: $VERSION" >&2; exit 1 ;;
  esac
}

apply_config() {
  local conf="/etc/sysctl.d/99-bbr-tune.conf"
  echo
  echo "正在写入 ${conf} ..."
  if [ "$(id -u)" -eq 0 ]; then
    printf '%s\n' "$CONFIG" > "$conf"
    sysctl -p "$conf"
  elif command -v sudo >/dev/null 2>&1; then
    printf '%s\n' "$CONFIG" | sudo tee "$conf" >/dev/null
    sudo sysctl -p "$conf"
  else
    printf '%s\n' "$CONFIG" > "$conf"
    sysctl -p "$conf"
  fi
  echo "[完成] 配置已生效"
}

show_summary() {
  echo
  line
  echo "已选择参数"
  line
  echo "版本: $(version_name "$VERSION")"
  echo "本地带宽: ${LOCAL_BW} Mbps"
  echo "服务器带宽: ${VPS_BW} Mbps"
  echo "输入延迟: ${RTT} ms"

  if [ "$RELAXED" -eq 1 ]; then
    echo "延迟宽松模式: 开启 (${RTT} -> ${REAL_RTT} ms)"
  else
    echo "延迟宽松模式: 关闭"
  fi

  if [[ "$VERSION" =~ ^(v3|v4|v5)$ ]]; then
    echo "内存: $(mem_name "$MEM")"
  fi

  if [[ "$VERSION" =~ ^(v4|v5)$ ]]; then
    echo "爬升曲线: $(ramp_name "$RAMP")"
  fi

  if [ "$VERSION" = "v5" ]; then
    echo "激进模式: $([ "$EXTREME" -eq 1 ] && echo "开启" || echo "关闭")"
  fi

  if [ "$VERSION" = "v1" ]; then
    echo "拥塞控制: BBR (固定)"
    echo "队列算法: FQ (固定)"
  else
    echo "拥塞控制: $(algo_name "$ALGO")"
    echo "队列算法: $(qdisc_name "$QDISC")"
  fi
  echo "写入系统: $([ "$APPLY" -eq 1 ] && echo "是" || echo "否")"
  line
}

main() {
  header

  choose_option VERSION "请选择版本：" 6 \
    "v1|V1 - 基础版" \
    "v2|V2 - 大带宽版" \
    "v25|V2.5 - 低丢包版" \
    "v3|V3 - 内存感知版" \
    "v4|V4 - 爬升曲线版" \
    "v5|V5 - 综合优化版（默认）"

  echo
  ask_int LOCAL_BW "请输入本地带宽 Mbps" 1000 1 100000
  ask_int VPS_BW "请输入服务器带宽 Mbps" 1000 1 100000
  ask_int RTT "请输入网络延迟 ms" 100 1 2000

  RELAXED=0
  if [[ "$VERSION" =~ ^(v2|v25)$ ]]; then
    echo
    ask_yesno RELAXED "是否开启网络延迟宽松模式（延迟值增加 20%）？" n
  fi

  MEM=1024
  if [[ "$VERSION" =~ ^(v3|v4)$ ]]; then
    echo
    choose_option MEM "请选择内存档位：" 3 \
      "256|256 MB 及以下" \
      "512|257-512 MB" \
      "1024|513 MB-1 GB" \
      "2048|大于 1 GB"
  elif [ "$VERSION" = "v5" ]; then
    echo
    choose_option MEM "请选择内存规格：" 5 \
      "128|128 MB" \
      "256|256 MB" \
      "512|512 MB" \
      "768|768 MB" \
      "1024|1 GB" \
      "1536|1.5 GB" \
      "2048|2 GB" \
      "3072|3 GB" \
      "4096|4 GB" \
      "8192|8 GB" \
      "16384|16 GB" \
      "32768|32 GB"
  fi

  RAMP=0.79
  if [[ "$VERSION" =~ ^(v4|v5)$ ]]; then
    echo
    choose_option RAMP "请选择爬升曲线档位：" 3 \
      "0.20|超平稳模式 (0.20) - 游戏 / 视频会议" \
      "0.50|平衡模式 (0.50) - 常规应用" \
      "0.79|高效模式 (0.79) - 流媒体 / 在线游戏（默认）" \
      "0.95|激进模式 (0.95) - 大文件 / 高速传输"
  fi

  ALGO=bbr
  QDISC=cake
  if [ "$VERSION" != "v1" ]; then
    echo
    choose_option ALGO "请选择拥塞控制算法：" 1 \
      "bbr|BBR" \
      "cubic|CUBIC"

    echo
    choose_option QDISC "请选择队列算法：" 2 \
      "fq|FQ" \
      "cake|CAKE" \
      "fq_pie|FQ_PIE"
  fi

  EXTREME=0
  if [ "$VERSION" = "v5" ]; then
    echo
    ask_yesno EXTREME "是否开启激进模式？" n
  fi

  echo
  ask_yesno APPLY "是否写入并立即生效？" n

  REAL_RTT="$RTT"
  if [ "$RELAXED" -eq 1 ]; then
    REAL_RTT=$(( (RTT * 12 + 9) / 10 ))
  fi

  CONFIG="$(generate_config)"
  show_summary
  echo
  echo "$CONFIG"

  if [ "$APPLY" -eq 1 ]; then
    apply_config
  fi
}

main "$@"
