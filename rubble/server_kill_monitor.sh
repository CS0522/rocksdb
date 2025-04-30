#!/usr/bin/env bash

if [ $# -lt 1 ]; then
    echo "server_kill_monitor.sh <pid_file>"
    exit
fi

pid_file=$1

if [ -f "${pid_file}" ]; then
  kill -9 $(cat "$pid_file")
  rm -f "$pid_file"
  echo "Monitor has been shut down"
else
  echo "No monitor is running"
fi

rm -rf "${pid_file}"
