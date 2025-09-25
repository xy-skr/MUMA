#!/usr/bin/env bash
#脚本框架
#开启严格模式,避免默默失败
set -euo pipefail
#防止路径名带空格时出问题
IFS=$'\n\t'
#添加一个基础日志函数
LOGFILE="./trojan_detector.log"

log() {
	#local限定作用域
	local level="$1"
	#将所有命令行参数左移一位，便于后续用$*输出日志内容
	shift
	#将格式化内容输出到日志文件
	printf '%s [%s] %s\n' "$(date '+%F %T')" "$level" "$*" | tee -a "$LOGFILE"
}
#添加一个cleanup函数并用trap绑定，脚本退出时自动收尾
#具体来说就是输出一句结尾到日志文件
cleanup() {
	log INFO "cleanup done."
}

trap cleanup EXIT

#创建基线表和收集表
DB='trojan_detector.db'
#初始化表结构
sqlite3 "$DB" <<EOF
CREATE TABLE IF NOT EXISTS baseline (
	category TEXT,
	key TEXT,
	value TEXT
);
CREATE TABLE IF NOT EXISTS collected (
	category TEXT,
	key TEXT,
	value TEXT
);
EOF
#收集器框架
#收集进程信息
collect_processes() {
	log INFO "=== Process List Start ==="
	ps -eo pid,ppid,user,cmd | tee -a "$LOGFILE" | tail -n +2 | \
	#每次读取输出的一行并跳过表头
	while read -r pid ppid user cmd; do
		sqlite3 "$DB" "INSERT INTO baseline (category, key, value)
			       VALUES ('process', '$pid:$cmd', '$user (ppid=$ppid)');"
	done
	log INFO "=== Process List End ==="
}
#收集网络连接
collect_network() {
	log INFO "=== Network List Start ==="
	ss -tulnp | tee -a "$LOGFILE" | tail -n +2 | \
	while read -r proto state local peer proc; do
		sqlite3 "$DB" "INSERT INTO baseline (category, key, value)
			       VALUES ('network', '$proto:$local', '$state $proc');"
	done
	log INFO "=== Network List End ==="
}
#收集系统自启动配置
collect_autostart() {
	#防止自动退出
	set +e
	
	log INFO "=== Autostart List Start ==="
	#显示用户自启动配置
	crontab -l 2>/dev/null | tee -a "$LOGFILE" | \
	while read -r line; do
		sqlite3 "$DB" "INSERT INTO baseline (category, key, value)
			       VALUES ('autostart', 'crontab:$USER', '$line');"
	done
	
	#显示系统自启动配置
	ls -l /etc/systemd/system/ /etc/rc*.d/ 2>/dev/null | tee -a "$LOGFILE" | \
	while read -r line; do
		sqlite3 "$DB" "INSERT INTO baseline (category, key, value)
			       VALUES ('autostart', 'system', '$line');"
	done
	
	set -e
	log INFO "=== Autostart List End ==="
}
#收集临时目录中的可执行文件
collect_files() {
	log INFO "=== File List Start ==="
	find /tmp /var/tmp /dev/shm -type f -executable -printf "%p %M %s\n" 2>/dev/null | tee -a "$LOGFILE" | \
	while read -r path perm size size; do
		sqlite3 "$DB" "INSERT INTO baseline (category, key, value)
			       VALUES ('file', '$path', 'perm=$perm size=$size');"
	done
	log INFO "=== File List End ==="
}
#收集器统一入口
collect_all() {
	log INFO "Collecting process info..."
	collect_processes
	
	log INFO "Collecting network info..."
	collect_network
	
	log INFO "Collecting autostart info..."
	collect_autostart
	
	log INFO "Collecting suspicious files..."
	collect_files	
}

collect_all
