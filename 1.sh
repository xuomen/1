#!/bin/bash

# 设置DEBIAN_FRONTEND环境变量，以便自动选择 "Yes"
export DEBIAN_FRONTEND=noninteractive

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
echo "deb http://ftp.debian.org/debian sid main non-free-firmware" | sudo tee /etc/apt/sources.list > /dev/null

# 更新软件包列表
apt update -y

# 升级所有已安装的软件包
apt upgrade -y

# 自动同意所有交互式提示
echo -e "Y\n" | sudo apt-get upgrade -y

# 执行发行版升级
apt full-upgrade -y

# 清理不再需要的软件包
apt autoremove -y

# 清理本地仓库
apt clean

# 安装必要的软件包
apt install -y curl wget bash

# 设置时区
timedatectl set-timezone Asia/Shanghai

# 清空motd文件
echo "" | sudo tee /etc/motd > /dev/null

echo "所有更新、升级和配置任务已完成。"
