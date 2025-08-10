#!/bin/bash

set -x

start_from_step=3
skip_install_driver=1

echo "Start from step: ${start_from_step}"
echo "Skip install driver: ${skip_install_driver}"

if [ $# -lt 6 ]; then
    echo "Usage: bash setup.sh username is_mlnx(0/1) shard_num IP-1 IP-2 IP-3 ..."
    exit
fi

ssh_arg="-o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ServerAliveInterval=30"
ssh_down=255
ssh_up=0

check_connectivity() {
    status=$1
    shift 1
    for ip in $@
    do
        while true
        do
            ssh $ssh_arg -q $username@$ip exit
            if [ $? -eq $status ]
            then
                break 1
            fi
        done
    done
}

username=$1
is_mlnx=$2
shard_num=$3
repo="https://raw.githubusercontent.com/CS0522/rocksdb-rubbledb"
branch="rubble"
script_path="rubble"

shift 3

# Step 1: configure SSH keys on each node
log=">> key_setup.log 2>&1"
if [ "${start_from_step}" -le 1 ]; then
    for ip in $@
    do
        scp $ssh_arg ~/.ssh/id_rsa.pub $username@$ip:~/
        ssh $ssh_arg $username@$ip "wget ${repo}/${branch}/${script_path}/setup-keys.sh ${log}; sudo bash setup-keys.sh ${log}"
        ssh $ssh_arg $username@$ip "sudo bash -c \"cat ~/id_rsa.pub >> /root/.ssh/authorized_keys\""
    done
fi

# Step 2: set up YCSB benchmark on IP-1
log=">> ycsb_build.log 2>&1"
ycsb_node=$1
shift 1
if [ "${start_from_step}" -le 2 ]; then
    ssh $ssh_arg root@$ycsb_node "sudo apt update ${log}; yes | sudo apt install maven python3-pip ${log}; sudo pip3 install matplotlib ${log}"
    ssh $ssh_arg root@$ycsb_node "git clone --branch rubble https://github.com/CS0522/YCSB-rubbledb.git YCSB ${log}; cd YCSB; nohup bash build.sh ${log} &"
fi

# Step 3: set up Rubble from IP-2 to IP-3
log=">> rubble_build.log 2>&1"
rubble_node=$@
rf=$#
if [ "${start_from_step}" -le 3 ]; then
    for ip in $rubble_node
    do
        ssh $ssh_arg root@$ip "wget ${repo}/${branch}/${script_path}/helper.sh ${log};"
        ssh $ssh_arg root@$ip "wget ${repo}/${branch}/${script_path}/setup-rubble.sh ${log}; bash setup-rubble.sh ${shard_num} ${rf} ${log}; umount /mnt/data" &
    done
    wait
fi

# Step 4: set up NVMeoF
# Step 4a: adjust iommu
log=">> iommu.log 2>&1"
if [ "${skip_install_driver}" -eq 0 ]; then
    for ip in $rubble_node
    do
        ssh $ssh_arg root@$ip "wget ${repo}/${branch}/${script_path}/set-iommu.sh ${log}"
        if [ $is_mlnx -eq 0 ]; then
            ssh $ssh_arg root@$ip "bash set-iommu.sh on ${log}" &
        else
            ssh $ssh_arg root@$ip "bash set-iommu.sh off ${log}" &
        fi
    done
    wait
    check_connectivity $ssh_up $rubble_node
fi

# Step 4b: install MLNX_OFED/Broadcom driver
log=">> driver.log 2>&1"
if [ "${skip_install_driver}" -eq 0 ]; then
    for ip in $rubble_node
    do
        if [ $is_mlnx -eq 1 ]; then
            param=""
            script_name="install-mlnx-ofed.sh"
        else
            param="1"
            script_name="install-broadcom-driver.sh"
        fi
        ssh $ssh_arg root@$ip "wget ${repo}/${branch}/${script_path}/${script_name} ${log}; nohup bash ${script_name} ${param} ${log} &"
    done
    # 这里老是会被阻塞住，得手动再关闭一次 Server 节点
    # 修改为只检测第一个节点是否关机
    check_connectivity $ssh_down ${rubble_node%% *}
    check_connectivity $ssh_up   $rubble_node
    if [ $is_mlnx -eq 0 ]; then
        param="2"
        for ip in $rubble_node; do
            ssh $ssh_arg root@$ip "nohup bash ${script_name} ${param} ${log} &"
        done
    fi
fi

# Step 4c: each node nvme-connects to its successor
log=">> nvmeof.log 2>&1"
if [ "${start_from_step}" -le 4 ]; then
    for ip in $rubble_node
    do
        ssh $ssh_arg root@$ip "wget ${repo}/${branch}/${script_path}/setup-nvmeof.sh ${log}; bash setup-nvmeof.sh target ${is_mlnx} ${rf} ${log}" &
    done
    wait
fi

rubble_node=( "$@" )
if [ "${start_from_step}" -le 4 ]; then
    for (( i=0; i<$rf; i++))
    do
        nvme_id=1
        for (( j=0; j<$rf; j++ ))
        do
            if [ $j -ne $i ]
            then
                k=$(( j + 2 ))
                ip=${rubble_node[$i]}
                next_ip='10.10.1.'$k
                ssh $ssh_arg root@$ip "bash setup-nvmeof.sh host ${next_ip} ${nvme_id} ${log}"
                nvme_id=$(( nvme_id + 1 ))
            fi
        done
    done
fi

# Step 5: misc
for ip in ${rubble_node[@]}
do
    ssh $ssh_arg root@$ip "mkswap /dev/sda4; swapon /dev/sda4;"
    ssh $ssh_arg root@$ip "bash -c 'echo core.%e.%p > /proc/sys/kernel/core_pattern'"
    ssh $ssh_arg root@$ip "mkdir ~/.config/procps"
    scp $ssh_arg toprc root@$ip:~/.config/procps/
    scp $ssh_arg dstat root@$ip:/usr/bin/dstat
done

echo "Done!"
