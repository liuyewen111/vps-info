#!/bin/bash

# ----------- 配置颜色 -----------
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # 无色

# ----------- 检查 root 权限 -----------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 root 权限运行此脚本${NC}"
    exit 1
fi

# ----------- 判断发行版名称 -----------
get_os_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$PRETTY_NAME"
    elif command -v lsb_release >/dev/null 2>&1; then
        OS="$(lsb_release -ds)"
    else
        OS="$(uname -s)"
    fi
    echo -e "${GREEN}系统版本: ${NC}$OS"
}

# ----------- 获取系统硬件信息 -----------
get_sys_info() {
    echo -e "${BLUE}=== 系统信息 ===${NC}"
    get_os_info
    echo -e "${GREEN}内核版本: ${NC}$(uname -r)"
    echo -e "${GREEN}架构: ${NC}$(uname -m)"
    echo -e "${GREEN}CPU 型号: ${NC}$(grep -m 1 "model name" /proc/cpuinfo | cut -d ':' -f2 | xargs)"
    echo -e "${GREEN}CPU 核心数: ${NC}$(nproc)"
    echo -e "${GREEN}运行时间: ${NC}$(uptime -p)"
}

# ----------- 获取内存和磁盘信息（根分区）-----------
get_memory_disk() {
    echo -e "\n${BLUE}=== 内存 / 磁盘 ===${NC}"

    # 内存信息
    free -h | awk '/^Mem:/ {print "内存总量:", $2, "已用:", $3, "空闲:", $4}'

    # 磁盘信息（只看 / 根分区，更准确更兼容）
    echo -ne "${GREEN}根分区磁盘使用: ${NC}"
    df -h / | awk 'NR==2 {print "总量:", $2, "已用:", $3, "空闲:", $4, "使用率:", $5}'
}

# ----------- 获取网络信息 -----------
get_network_info() {
    echo -e "\n${BLUE}=== 网络信息 ===${NC}"
    IP4=$(curl -s4 --max-time 4 ip.sb)
    IP6=$(curl -s6 --max-time 4 ip.sb)
    echo -e "${GREEN}公网 IPv4: ${NC}${IP4:-无法获取}"
    echo -e "${GREEN}公网 IPv6: ${NC}${IP6:-无法获取}"
    echo -e "${GREEN}默认网关: ${NC}$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -n1)"
    echo -e "${GREEN}DNS 服务器: ${NC}$(grep -v '^#' /etc/resolv.conf | grep nameserver | awk '{print $2}' | paste -sd ', ')"
}

# ----------- 虚拟化检测 -----------
get_virtualization() {
    echo -e "\n${BLUE}=== 虚拟化环境 ===${NC}"
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        VIRT=$(systemd-detect-virt)
        echo -e "${GREEN}虚拟化类型: ${NC}${VIRT:-未知}"
    else
        echo -e "${RED}无法检测虚拟化（缺少 systemd-detect-virt）${NC}"
    fi
}

# ----------- 主函数 -----------
main() {
    echo -e "${YELLOW}VPS 信息检测脚本 - by vps-info${NC}"
    echo -e "${YELLOW}检测时间: $(date)${NC}"
    echo "-------------------------------------------"
    get_sys_info
    get_memory_disk
    get_network_info
    get_virtualization
    echo -e "\n${YELLOW}检测完成 🎉${NC}"
}

main
