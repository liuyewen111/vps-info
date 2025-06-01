#!/bin/bash

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BLUE="\033[34m"
NC="\033[0m" # 无颜色

check_and_install_deps() {
    echo -e "${YELLOW}=== 检查并安装必要依赖 ===${NC}"
    REQUIRED_CMDS=("curl" "jq")
    MISSING_CMDS=()

    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            MISSING_CMDS+=("$cmd")
        fi
    done

    if [ ${#MISSING_CMDS[@]} -eq 0 ]; then
        echo -e "${GREEN}所有必要依赖已安装${NC}"
        return
    fi

    echo -e "${RED}缺少依赖: ${MISSING_CMDS[*]}，尝试自动安装...${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
    else
        echo -e "${RED}无法识别操作系统，请手动安装: ${MISSING_CMDS[*]}${NC}"
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
        echo -e "${RED}不支持的系统：$OS_ID，请手动安装: ${MISSING_CMDS[*]}${NC}"
    fi
}

print_line() {
    printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '-'
}

get_sys_info() {
    echo -e "${CYAN}🚀 系统信息${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        printf " %-15s : %s\n" "系统版本" "$PRETTY_NAME"
    else
        printf " %-15s : %s\n" "系统版本" "$(uname -s)"
    fi
    printf " %-15s : %s\n" "内核版本" "$(uname -r)"
    printf " %-15s : %s\n" "架构" "$(uname -m)"
    CPU_MODEL=$(grep -m 1 "model name" /proc/cpuinfo | cut -d ':' -f2 | xargs)
    printf " %-15s : %s\n" "CPU 型号" "$CPU_MODEL"
    printf " %-15s : %d\n" "CPU 核心数" "$(nproc)"
    printf " %-15s : %s\n" "运行时间" "$(uptime -p)"
    BOOT_TIME=$(who -b | awk '{print $3, $4}')
    printf " %-15s : %s\n" "启动时间" "$BOOT_TIME"
    print_line
}

get_memory_disk() {
    echo -e "${CYAN}💾 内存 / 磁盘${NC}"
    MEM_INFO=$(free -h | awk '/^Mem:/ {print "总量: "$2", 已用: "$3", 空闲: "$4}')
    printf " %-15s : %s\n" "内存" "$MEM_INFO"
    DISK_INFO=$(df -h / | awk 'NR==2 {print "总量: "$2", 已用: "$3", 空闲: "$4", 使用率: "$5}')
    printf " %-15s : %s\n" "根分区" "$DISK_INFO"
    print_line
}

get_network_info() {
    echo -e "${CYAN}🌐 网络信息${NC}"
    IP4=$(curl -s4 --max-time 4 ip.sb)
    IP6=$(curl -s6 --max-time 4 ip.sb)
    printf " %-15s : %s\n" "公网 IPv4" "${IP4:-获取失败}"
    printf " %-15s : %s\n" "公网 IPv6" "${IP6:-获取失败}"
    GATEWAY=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1)
    printf " %-15s : %s\n" "默认网关" "$GATEWAY"
    DNS=$(grep -v '^#' /etc/resolv.conf | grep nameserver | awk '{print $2}' | paste -sd ', ')
    printf " %-15s : %s\n" "DNS 服务器" "$DNS"

    echo -e "${YELLOW}IP 地理位置：${NC}"
    curl -s "http://ip-api.com/json" | jq -r '
        "  国家 : \(.country)\n  省份 : \(.regionName)\n  城市 : \(.city)\n  运营商 : \(.isp)"' 2>/dev/null || echo "  获取失败"
    print_line
}

check_ports() {
    echo -e "${CYAN}🔌 常用端口检测${NC}"
    for port in 22 80 443; do
        if timeout 2 bash -c "</dev/tcp/127.0.0.1/$port" &>/dev/null; then
            echo -e " 端口 ${GREEN}$port${NC} : ${GREEN}开放${NC}"
        else
            echo -e " 端口 ${RED}$port${NC} : ${RED}未开放${NC}"
        fi
    done
    print_line
}

check_firewall() {
    echo -e "${CYAN}🔒 防火墙状态${NC}"
    if command -v ufw &>/dev/null; then
        echo "UFW 状态:"
        ufw status verbose
    elif command -v iptables &>/dev/null; then
        echo "iptables 规则:"
        iptables -L -n
    else
        echo "未检测到防火墙工具"
    fi
    print_line
}

check_load() {
    echo -e "${CYAN}📊 系统负载状态${NC}"
    LOAD=$(uptime | awk -F 'load average:' '{print $2}' | xargs)
    PROC_NUM=$(ps -ef | wc -l)
    echo "当前负载 : $LOAD"
    echo "进程数量 : $PROC_NUM"
    print_line
}

get_virtualization() {
    echo -e "${CYAN}🖥️ 虚拟化类型${NC}"
    if command -v systemd-detect-virt &>/dev/null; then
        VIRT=$(systemd-detect-virt)
        echo "虚拟化类型 : $VIRT"
    else
        echo "未安装 systemd-detect-virt，跳过虚拟化检测"
    fi
    print_line
}

main() {
    check_and_install_deps
    echo -e "${YELLOW}VPS 信息检测脚本 - by vps-info${NC}"
    echo "检测时间: $(date)"
    print_line
    get_sys_info
    get_memory_disk
    get_network_info
    check_ports
    check_firewall
    check_load
    get_virtualization
    echo -e "${GREEN}检测完成${NC}"
}

main
