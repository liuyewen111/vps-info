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

# ----------- 获取内存和磁盘信息 -----------
get_memory_disk() {
    echo -e "\n${BLUE}=== 内存 / 磁盘 ===${NC}"
    free -h | awk '/^Mem:/ {print "内存总量:", $2, "已用:", $3, "空闲:", $4}'
    df -h --total | grep total | awk '{print "磁盘总量:", $2, "已用:", $3, "空闲:", $4, "使用率:", $5}'
}

# ----------- 获取网络信息 -----------
get_network_info() {
    echo -e "\n${BLUE}=== 网络信息 ===${NC}"
    IP4=$(curl -s4 --max-time 4 ip.sb)
    IP6=$(curl -s6 --max-time 4 ip.sb)
    echo -e "${GREEN}公网 IPv4: ${NC}${IP4:-无法获取}"
    echo -e "${GREEN}公网 IPv6: ${NC}${IP6:-无法获取}"
    echo -e "${GREEN}默认网关: ${NC}$(ip route | grep default | awk '{print $3}' | head -n1)"
    echo -e "${GREEN}DNS 服务器: ${NC}$(cat /etc/resolv.conf | grep -v '^#' | grep nameserver | awk '{print $2}' | paste -sd ', ')"
}

# ----------- 虚拟化检测 -----------
get_virtualization() {
    echo -e "\n${BLUE}=== 虚拟化环境 ===${NC}"
    VIRT=$(systemd-detect-virt)
    echo -e "${GREEN}虚拟化类型: ${NC}${VIRT:-未知}"
}

# ----------- 主函数 -----------
main() {
    echo -e "${YELLOW}VPS 信息检测脚本 - by ChatGPT + 刘烨汶${NC}"
    echo -e "${YELLOW}检测时间: $(date)${NC}"
    echo "-------------------------------------------"
    get_sys_info
    get_memory_disk
    get_network_info
    get_virtualization
    echo -e "\n${YELLOW}检测完成 🎉${NC}"
}

main
