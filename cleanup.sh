#!/bin/sh
# cleanup.sh <server> <volume> <router> <network> <subnet> <port> <keypair> [<public_ip>]

if [ $# -lt 7 ]
then
  echo 1>&2 "Usage: $0 <server> <volume> <router> <network> <subnet> <port> <keypair> [<public_ip>]"
  exit 1
fi

echo "Cleanup started $(date)"
echo "$@"

SERVER=$1
VOLUME=$2
ROUTER=$3
NETWORK=$4
SUBNET=$5
PORT=$6
KEYPAIR=$7
IP=""

if [ ! -z $8 ]
then
  IP=$8
  openstack floating ip delete $IP
  echo "Public IP $IP deleted"
fi

openstack server stop $SERVER
sleep 5
echo "Server $SERVER stopped"

openstack router remove port $ROUTER $PORT
echo "Port $PORT removed from router $ROUTER"

openstack port delete $PORT
echo "Port $PORT deleted"

openstack router remove subnet $ROUTER $SUBNET
echo "Subnet $SUBNET removed from router $ROUTER"

openstack subnet delete $SUBNET
echo "Subnet $SUBNET deleted"

openstack network delete $NETWORK
echo "Network $NETWORK deleted"

openstack router delete $ROUTER
echo "Router $ROUTER deleted"

openstack server delete --wait $SERVER
echo "Server $SERVER deleted"

openstack volume delete $VOLUME
echo "Volume $VOLUME deleted"

openstack keypair delete $KEYPAIR
echo "Keypair $KEYPAIR deleted"

echo "Cleanup completed $(date)"

ls
