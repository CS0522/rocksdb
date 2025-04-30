#!/usr/bin/env bash

if [ $# -lt 2 ]; then
    echo "server_start_monitor.sh <sample_interval> <monitor_output_file> 2>&1 &"
    exit
fi

# Configs
sample_interval=$1
monitor_output_file=$2
# 监控 db_node
target_process="db_node"

# 延迟 10s 启动
# sleep 10

mkdir -p /tmp

# Detect if target process is running, if not, do nothing
# accumulate if exists multiple same process
while :; do
  ps -C "${target_process}" -o %cpu --no-headers | 
    awk '{sum += $1} END {print sum+0}' >> "${monitor_output_file}"
  sleep ${sample_interval}
done
