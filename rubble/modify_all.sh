#!/usr/bin/env bash

function usage()
{
  echo "Usage: bash modify_all.sh <username>"
  exit
}

if [ $# != 1 ]; then
  usage
fi

# all nodes' hostnames
hostnames=("clnode261.clemson.cloudlab.us" "clnode265.clemson.cloudlab.us" "clnode256.clemson.cloudlab.us" "clnode257.clemson.cloudlab.us")
# client hostname
client="clnode261.clemson.cloudlab.us"
# servers hostnames
servers=("clnode265.clemson.cloudlab.us" "clnode256.clemson.cloudlab.us" "clnode257.clemson.cloudlab.us")

username=$1

echo "Username: ${username}"
echo "Client hostname: ${client}"
echo -n "Server hostnames: "
for s in ${servers[@]}; do
    echo -n "${s} "
done
echo ''

ssh_arg="-o ConnectTimeout=10 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ServerAliveInterval=30"
scp_arg="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

function upload_config_ini()
{
  for server in ${servers[@]}; do
    ssh ${ssh_arg} ${username}@${server} << ENDSSH
      sudo rm -rf /mnt/data/rocksdb/rubble/rubble_16gb_config.ini
      sudo rm -rf /mnt/data/rocksdb/rubble/rubble_16gb_config_tail.ini
      cd /mnt/data/rocksdb/rubble
      sudo wget https://raw.githubusercontent.com/CS0522/rocksdb-rubbledb/rubble/rubble/rubble_16gb_config.ini
      sudo wget https://raw.githubusercontent.com/CS0522/rocksdb-rubbledb/rubble/rubble/rubble_16gb_config_tail.ini
      sudo sed -i "s/max_write_buffer_number=[0-9]\+/max_write_buffer_number=2/g" /mnt/data/rocksdb/rubble/rubble_16gb_config_tail.ini
		  exit
ENDSSH
    # upload
    # scp ${scp_arg} ./rubble_16gb_config.ini ${username}@${server}:/mnt/data/rocksdb/rubble
    # scp ${scp_arg} ./rubble_16gb_config_tail.ini ${username}@${server}:/mnt/data/rocksdb/rubble
  done
}

function update_config_ini()
{
  for server in ${servers[@]}; do
    ssh ${ssh_arg} ${username}@${server} << ENDSSH
      sudo sed -i "s/max_write_buffer_number=[0-9]\+/max_write_buffer_number=128/g" /mnt/data/rocksdb/rubble/rubble_16gb_config_tail.ini
		  exit
ENDSSH
  done
}

# upload_config_ini
update_config_ini