#!/bin/expect -f -

# 设置sudo密码
set password "your_sudo_password"

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
    expect "password" { send "$password\r" }
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
    spawn sudo sed -i 's/^Storage=.*/Storage=none/' /
