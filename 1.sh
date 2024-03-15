#!/usr/bin/expect -f

# 检查sudo是否已安装，如果没有则安装sudo
if {[catch {exec sudo -n true}]} {
    puts "sudo 未安装，正在安装..."
    spawn apt update && apt install -y sudo
    expect "press Enter to continue or Ctrl+C to cancel adding it" { send "\r" }
    expect eof
}

# 确保脚本以root用户执行，如果不是，则使用sudo提升权限
if {![catch {exec sudo -n true}]} {
    puts "正在以root用户身份执行脚本..."
} else {
    spawn sudo -E "$argv0" "$@"
    expect "password" { send "$env(SUDO_PASSWORD)\r" }
    expect eof
    exit 0
}

# 设置dpkg选项以自动处理配置文件的冲突
spawn dpkg --configure -a
expect eof

spawn sudo debconf-set-selections <<< 'debconf debconf/frontend select Noninteractive'
expect eof
spawn sudo debconf-set-selections <<< 'libc6 libraries/restart-without-asking boolean true'
expect eof

# 配置systemd journald服务
set journald_storage [exec grep "^Storage=" /etc/systemd/journald.conf]
if {[string length $journald_storage] > 0} {
    spawn sudo sed -i 's/^Storage=.*/Storage=none/' /etc/systemd/journald.conf
    expect eof
} else {
    spawn sudo sh -c "echo 'Storage=none' >> /etc/systemd/journald.conf"
    expect eof
}
spawn sudo systemctl restart systemd-journald
expect eof

# 设置sshd_config选项，以自动安装维护者提供的sshd_config版本
spawn sudo debconf-set-selections <<< 'sshd_config select install the package maintainer'"'"'s version'
expect eof

# 设置debconf选项，写入新的源到sources.list文件
spawn sudo sh -c "echo -e 'deb http://ftp.debian.org/debian sid main non-free-firmware\ndeb-src http://ftp.debian.org/debian sid main non-free-firmware' > /etc/apt/sources.list"
expect eof

# 根据CPU支持的指令集级别安装相应的Linux内核
spawn sudo apt update && sudo apt install -y wget gnupg
expect eof
spawn wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg --yes
expect eof
spawn sudo sh -c "echo 'deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list"
expect eof
spawn sudo apt update
expect eof
spawn sudo apt install -y linux-xanmod-x64v
expect eof

# 升级所有已安装的软件包
spawn sudo apt upgrade -y
expect eof

# 执行发行版升级
spawn sudo apt full-upgrade -y
expect eof

# 安装必要的软件包
spawn sudo apt install -y curl wget bash tuned ncdu
expect eof

# 设置时区
spawn sudo timedatectl set-timezone Asia/Shanghai
expect eof

# 清空motd文件
spawn sudo sh -c "echo '' > /etc/motd"
expect eof

# 完成所有更新、升级和配置任务后将标志文件设置为已重启
spawn sudo touch /var/tmp/rebooted.flag
expect eof

# 如果系统已重启，则继续执行重启后的任务
if {[file exists "/var/tmp/rebooted.flag"]} {
    # 重启tuned服务并设置其开机自启
    spawn sudo systemctl start tuned.service
    expect eof
    spawn sudo systemctl enable tuned.service
    expect eof
    spawn sudo tuned-adm profile realtime-virtual-guest
    expect eof
    
    # 清理系统
    spawn sudo apt-get autoclean
    expect eof
    spawn sudo apt-get clean
    expect eof
    spawn sudo apt-get autoremove
    expect eof
    spawn sudo apt autoremove
    expect eof
    spawn sudo apt autoclean
    expect eof
    spawn sudo find / -type f \( -name "*~" -o -name "*-" -o -name "*.tmp" -o -name "*.bak" -o -name "*.swp" -o -name "*.cache" -o -name "*.log" -o -name "*.old" -o -name "*.swp" \) -exec rm {} +
    expect eof
    spawn sudo apt autoremove --purge
    expect eof
    spawn sudo apt clean
    expect eof
    spawn sudo apt autoclean
    expect eof
    spawn sudo apt remove --purge $(dpkg -l | awk '/^rc/ {print $2}')
    expect eof
    
    # 旋转并清理journalctl日志
    spawn sudo journalctl --rotate
    expect eof
    spawn sudo journalctl --vacuum-time=1s
    expect eof
    spawn sudo journalctl --vacuum-size=50M
    expect eof
    
    # 删除非当前内核版本的内核镜像和头文件
    spawn sudo apt remove --purge $(dpkg -l | awk '/^ii linux-(image|headers)-[^ ]+/{print $2}' | grep -v $(uname -r | sed 's/-.*//') | xargs)
    expect eof
    
    # 清理无用的软件包
    spawn sudo dpkg -l | grep ^rc | awk '{print $2}' | sudo xargs dpkg -P
    expect eof
    spawn sudo dpkg -l | grep "^rc" | awk '{print $2}' | xargs sudo aptitude -y purge
    expect eof
    
    # 更新grub
    spawn sudo update-grub
    expect eof

    # 重启系统
    spawn sudo reboot
    expect eof
}

# 删除标志文件，以便下次脚本运行时可以再次进行重启后的任务
spawn sudo rm -f /var/tmp/rebooted.flag
expect eof

# 更新版本信息
spawn sudo sh -c "echo '12.5' >> /etc/debian_version"
expect eof
spawn sudo sh -c "echo -e 'Debian GNU/Linux 12 \\n \\l' >> /etc/issue"
expect eof
spawn sudo sh -c "echo -e 'PRETTY_NAME=\"Debian GNU/Linux 12 (bookworm)\"\nNAME=\"Debian GNU/Linux\"\nVERSION_ID=\"12\"\nVERSION=\"12 (book
