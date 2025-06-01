#!/bin/bash

# ----------- 检查 root 权限 -----------
if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# ----------- 自动安装依赖 -----------
check_and_install_deps() {
    echo "=== 检查并安装必要依赖 ==="
    REQUIRED_CMDS=("curl" "jq")
    MISSING_CMDS=()

    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            MISSING_CMDS+=("$cmd")
        fi
    done

    if [ ${#MISSING_CMDS[@]} -eq 0 ]; then
        echo "所有必要依赖已安装"
        return
    fi

    echo "缺少依赖: ${MISSING_CMDS[*]}，尝试自动安装..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
    else
        echo "无法识别操作系统，请手动安装: ${MISSING_CMDS[*]}"
        return
    fi

    if [[ "$OS_ID" =~ ^(debian|ubuntu)$ ]]; then
        apt update -y && apt install -y "${MISSING_CMDS[@]}"
    elif [[ "$OS_ID" =~ ^(centos|rocky|almalinux|rhel)$ ]]; then
        yum install -y "${MISSING_CMDS[@]}"
    elif [[ "$OS_ID" == "alpine" ]]; then
        apk add --no-cache "${MISSING_CMDS[@]}"
    elif [[ "$OS_ID" == "arch" ]]; then
        pacman -Sy --noconfirm "${MISSING_CMDS[@]}"
    else
        echo "不支持的系统：$OS_ID，请手动安装: ${MISSING_CMDS[*]}"
    fi
}

# ----------- 系统信息 -----------
get_sys_info() {
    echo "=== 系统信息 ==="
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "系统版本: $PRETTY_NAME"
    else
        echo "系统版本: $(uname -s)"
    fi
    echo "内核版本: $(uname -r)"
    echo "架构: $(uname -m)"
    echo "CPU 型号: $(grep -m 1 "model name" /proc/cpuinfo | cut -d ':' -f2 | xargs)"
    echo "CPU 核心数: $(nproc)"
    echo "运行时间: $(uptime -p)"
    echo "启动时间: $(who -b | awk '{print $3, $4}')"
}

# ----------- 内存与磁盘 -----------
get_memory_disk() {
    echo
    echo "=== 内存 / 磁盘 ==="
    free -h | awk '/^Mem:/ {print "内存总量:", $2, "已用:", $3, "空闲:", $4}'
    echo -n "根分区磁盘使用: "
    df -h / | awk 'NR==2 {print "总量:", $2, "已用:", $3, "空闲:", $4, "使用率:", $5}'
}

# ----------- 网络信息 + IP 地理位置 -----------
get_network_info() {
    echo
    echo "=== 网络信息 ==="
    IP4=$(curl -s4 --max-time 4 ip.sb)
    IP6=$(curl -s6 --max-time 4 ip.sb)
    echo "公网 IPv4: ${IP4:-获取失败}"
    echo "公网 IPv6: ${IP6:-获取失败}"
    echo "默认网关: $(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1)"
    echo "DNS 服务器: $(grep -v '^#' /etc/resolv.conf | grep nameserver | awk '{print $2}' | paste -sd ', ')"

    echo "IP 地理位置:"
    curl -s "http://ip-api.com/json" | jq -r '"  国家: \(.country)\n  省份: \(.regionName)\n  城市: \(.city)\n  运营商: \(.isp)"' 2>/dev/null || echo "  获取失败"
}

# ----------- 网络端口检测 -----------
check_ports() {
    echo
    echo "=== 常用端口检测 ==="
    for port in 22 80 443; do
        if timeout 2 bash -c "</dev/tcp/127.0.0.1/$port" &>/dev/null; then
            echo "端口 $port: 开放"
        else
            echo "端口 $port: 未开放"
        fi
    done
}

# ----------- 防火墙状态 -----------
check_firewall() {
    echo
    echo "=== 防火墙状态 ==="
    if command -v ufw >/dev/null 2>&1; then
        echo "UFW 状态:"
        ufw status verbose
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables 规则:"
        iptables -L -n
    else
        echo "未检测到防火墙工具"
    fi
}

# ----------- 系统负载状态 -----------
check_load() {
    echo
    echo "=== 系统负载状态 ==="
    echo "当前负载: $(uptime | awk -F 'load average:' '{print $2}' | xargs)"
    echo "进程数量: $(ps -ef | wc -l)"
}

# ----------- 虚拟化检测 -----------
get_virtualization() {
    echo
    echo "=== 虚拟化类型 ==="
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        echo "虚拟化类型: $(systemd-detect-virt)"
    else
        echo "未安装 systemd-detect-virt，跳过虚拟化检测"
    fi
}

# ----------- 主程序 -----------
main() {
    check_and_install_deps
    echo "VPS 信息检测脚本 - by vps-info"
    echo "检测时间: $(date)"
    echo "-------------------------------------------"
    get_sys_info
    get_memory_disk
    get_network_info
    check_ports
    check_firewall
    check_load
    get_virtualization
    echo
    echo "检测完成"
}

main
