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

#收集器框架
#收集进程信息
collect_processes() {
	log INFO "=== Process List Start ==="
	ps -eo pid,ppid,user,cmd | tee -a "$LOGFILE"
	log INFO "=== Process List End ==="
}
#收集网络连接
collect_network() {
	log INFO "=== Network List Start ==="
	ss -tulnp | tee -a "$LOGFILE"
	log INFO "=== Network List End ==="
}
#收集系统自启动配置
collect_autostart() {
	#防止自动退出
	set +e
	
	log INFO "=== Autostart List Start ==="
	#显示用户自启动配置
	crontab -l 2>/dev/null | tee -a "$LOGFILE"
	#必须处理返回值，否则脚本会自动退出
	if [ $? -ne 0 ]; then
		log WARN "User crontab failed to read"
	fi
	#显示系统自启动配置
	ls -l /etc/systemd/system/ /etc/rc*.d/ 2>/dev/null | tee -a "$LOGFILE"
	if [ $? -ne 0 ]; then
		log WARN "System autostart failed to read"
	fi
	
	set -e
	log INFO "=== Autostart List End ==="
}
#收集临时目录中的可执行文件
collect_files() {
	log INFO "=== File List Start ==="
	find /tmp /var/tmp /dev/shm -type f -executable 2>/dev/null | tee -a "$LOGFILE"
	if [ $? -ne 0 ]; then
		log WARN "Executable file failed to read"
	fi
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
