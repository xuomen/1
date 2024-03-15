#!/bin/bash
REBOOT_FLAG="/var/tmp/rebooted.flag"

# 检查sudo是否已安装，如果没有则安装sudo
if ! command -v sudo &> /dev/null; then
    echo "sudo 未安装，正在安装..."
    apt update -y && apt install -y sudo
fi

# 确保脚本以root用户执行，如果不是，则使用sudo提升权限
if [ "$(id -u)" -ne 0 ]; then
    echo "正在以root用户身份执行脚本..."
    sudo -E "$0" "$@"
    exit 0
fi

# 设置dpkg选项以自动处理配置文件的冲突
export DPKG_OPTIONS='--force-confnew'
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
echo 'libc6 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
# 配置systemd journald服务
if grep -q "^Storage=" /etc/systemd/journald.conf; then
    sudo sed -i 's/^Storage=.*/Storage=none/' /etc/systemd/journald.conf
else
    echo "Storage=none" | sudo tee -a /etc/systemd/journald.conf > /dev/null
fi
sudo systemctl restart systemd-journald

# 设置sshd_config选项，以自动安装维护者提供的sshd_config版本
echo "sshd_config select install the package maintainer's version" | sudo debconf-set-selections

# 设置debconf选项，写入新的源到sources.list文件
echo -e "deb http://ftp.debian.org/debian sid main non-free-firmware\ndeb-src http://ftp.debian.org/debian sid main non-free-firmware" | sudo tee /etc/apt/sources.list > /dev/null

# 根据CPU支持的指令集级别安装相应的Linux内核
echo -e "Y\n" | apt update -y && echo -e "Y\n" | apt install -y wget gnupg && wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg --yes && echo 'deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-release.list && sudo apt update && sudo apt install -y linux-xanmod-x64vsudo apt install -y linux-xanmod-x64v$(awk 'BEGIN { while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1 && if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1 && if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2 && if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3 && if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4 && if (level > 0) { print level && exit level + 1 } exit 1 }') -y && reboot


# 升级所有已安装的软件包
echo -e "Y\n" | sudo apt upgrade -y

# 执行发行版升级
echo -e "Y\n" | sudo apt full-upgrade -y

# 安装必要的软件包
apt install -y curl wget bash tuned ncdu

# 设置时区
timedatectl set-timezone Asia/Shanghai

# 清空motd文件
echo "" | sudo tee /etc/motd > /dev/null

# 完成所有更新、升级和配置任务后将标志文件设置为已重启
touch $REBOOT_FLAG

# 如果系统已重启，则继续执行重启后的任务
if [ -f "$REBOOT_FLAG" ]; then
    # 在这里添加需要在重启后继续执行的任务
    echo "正在执行重启后的任务..."
    
    # 重启tuned服务并设置其开机自启
    sudo systemctl start tuned.service
    sudo systemctl enable tuned.service
    sudo tuned-adm profile realtime-virtual-guest
    
    # 清理系统
    apt-get autoclean -y
    apt-get clean -y
    apt-get autoremove -y
    apt autoremove -y
    apt autoclean -y
    find / -type f \( -name "*~" -o -name "*-" -o -name "*.tmp" -o -name "*.bak" -o -name "*.swp" -o -name "*.cache" -o -name "*.log" -o -name "*.old" -o -name "*.swp" \) -exec rm {} +
    apt autoremove --purge -y
    apt clean
    apt autoclean
    apt remove --purge -y $(dpkg -l | awk '/^rc/ {print $2}')
    
    # 旋转并清理journalctl日志
    sudo journalctl --rotate
    sudo journalctl --vacuum-time=1s
    sudo journalctl --vacuum-size=50M
    
    # 删除非当前内核版本的内核镜像和头文件
    sudo apt remove --purge -y $(dpkg -l | awk '/^ii linux-(image|headers)-[^ ]+/{print $2}' | grep -v $(uname -r | sed 's/-.*//') | xargs)
    
    # 清理无用的软件包
    dpkg -l |grep ^rc|awk '{print $2}' |sudo xargs dpkg -P
    dpkg -l |grep "^rc"|awk '{print $2}' |xargs aptitude -y purge
    
    
    # 更新grub
    sudo update-grub

    # 重启系统
    reboot
fi

# 删除标志文件，以便下次脚本运行时可以再次进行重启后的任务
rm -f $REBOOT_FLAG

echo "12.5" | sudo tee -a /etc/debian_version > /dev/null
echo -e "Debian GNU/Linux 12 \\n \\l" | sudo tee -a /etc/issue > /dev/null
echo -e 'PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"\nNAME="Debian GNU/Linux"\nVERSION_ID="12"\nVERSION="12 (bookworm)"\nVERSION_CODENAME=bookworm\nID=debian\nHOME_URL="https://www.debian.org/"\nSUPPORT_URL="https://www.debian.org/support"\nBUG_REPORT_URL="https://bugs.debian.org/"' | sudo tee -a /etc/os-release > /dev/null

echo "所有更新、升级和配置任务已完成。"
