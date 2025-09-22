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

