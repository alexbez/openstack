#!/bin/sh
# deploy.sh <server_name> <server_flavor> <disk_size> <router> <network> <subnet_name> <port> <keypair>
#

#set -eu

if [ $# -ne 8 ]
then
  echo 1>&2 "Usage: $0 <server_name> <server_flavor> <disk_size> <router> <network> <subnet> <port> <keypair>"
  echo 1>&2 "Limitation: No public IP yet!"
  exit 1
fi

SERV_NAME=$1
FLAVOR=$2
DISK_SIZE=$3
ROUTER=$4
NETWORK=$5
SUBNET=$6
PORT=$7
KEYPAIR=$8

IMAGE_ID="9dae17b7-f917-4324-8795-cbf62a2bbdad"
#IMAGE_ID=""
IMAGE_NAME="RHEL-7.4-OCP-base"

echo "Deployment started $(date)"

# Check if the router exists
ROUTER_ID=$(openstack router list -f json | jq " .[] | select(.Name==\"$ROUTER\") | .ID ")

if [ -z "$ROUTER_ID" ]
then
  echo 1>&2 "Router $ROUTER does not exist. Creting it."
  $ROUTER_ID=$(openstack router create $ROUTER -f json | jq ".[] | .ID")
fi

if [ -z "$ROUTER_ID" ]
then
  echo 1>&2 "Cannot create router $ROUTER. Aborting."
  exit 2
fi

echo "ROUTER_ID: " $ROUTER_ID

#Check if the network exists
NETWORK_ID=$(openstack network list -f json | jq " .[] | select(.Name==\"$NETWORK\") | .ID")

if [ -z "$NETWORK_ID" ]
then
  echo 1>&2 "Network $NETWORK does not exist. Creating it"
  NETWORK_ID=$(openstack network create $NETWORK -f json | jq " .[] .ID")
fi

if [ -z "$NETWORK_ID" ]
then
  echo 1>&2 "Cannot create network $NETWORK. Aborting"
  exit 3
fi

echo "Network ID: " $NETWORK_ID

# Check if the subnet exists
SUBNET_ID=$(openstack subnet list -f json | jq " .[] | select(.Name==\"$SUBNET\") | .ID")
echo #1 SUBNET_ID="$SUBNET_ID"
if [ -z "$SUBNET_ID" ]
then
  echo 1>&2 "Subnet $SUBNET does not exist. Creating it."
  openstack 1>/dev/null subnet create --network $NETWORK --subnet-range "192.168.10.0/24" $SUBNET -f json 

  SUBNET_ID=$(openstack subnet list -f json | jq " .[] | select(.Name==\"$SUBNET\") | .ID")
fi

if [ -z "$SUBNET_ID" ]
then
  echo 1>&2 "Cannot create subnet $SUBNET. Aborting."
  exit 4
fi

echo "Subnet ID: " $SUBNET_ID

openstack router add subnet $ROUTER $SUBNET
echo "Subnet $SUBNET added to the router $ROUTER"

# Check if the port exists
PORT_ID=$(openstack port create --network $NETWORK $PORT -f json | jq ".id")
if [ -z "$PORT_ID" ]
then
  echo 1>&2 "Cannot create port $PORT. Aborting"
  exit 5
fi

temp="${PORT_ID%\"}"
temp="${temp#\"}"
PORT_ID=$temp

echo "Port ID: " $PORT_ID


# Check if the keypair exists

KEYPAIR_ID=$(openstack keypair list -f json | jq " .[] | select(.Name==\"$KEYPAIR\") | .Name" )
if [ -z "$KEYPAIR_ID" ]
then
  echo 1>&2 "Keypair $KEYPAIR does not exist. Creating it"
  openstack keypair create $KEYPAIR --public-key ~/.ssh/id_rsa.pub
fi
echo "Keypair: " $KEYPAIR


# Get image ID for the OS disk if it is not specified already
if [ -z "$IMAGE_ID" ]
then
  echo "IMAGE_ID is not defined, seeking image by name $IMAGE_NAME"
  IMAGE_ID=$(openstack image list -f json | jq " .[] | select(.Name==\"$IMAGE_NAME\") | .ID")
fi
  
if [ -z "$IMAGE_ID" ]
then
  echo 1>&2 "Image $IMAGE_NAME does not exist"
  exit 7
fi

echo "Image ID: " $IMAGE_ID

# Check if the OS volume already exist
######
# TODO
######

# Creating system volume from image
OS_VOLUME_NAME=$SERV_NAME-os-volume
echo "OS Volume Name: " $OS_VOLUME_NAME


# Removing first and last '"' char from the IMAGE_ID
temp="${IMAGE_ID%\"}"
temp="${temp#\"}"
IMAGE_ID=$temp

echo "Stripped IMAGE_ID: " $IMAGE_ID

OS_VOLUME_ID=$(openstack volume create $OS_VOLUME_NAME --size $DISK_SIZE --type SATA --availability-zone "eu-de-02" --image $IMAGE_ID -f json | jq ".id")

echo "OS Volume ID: " $OS_VOLUME_ID
echo "Volume is being created..."


STATUS=$(openstack volume list --name $OS_VOLUME_NAME -f json | jq ".[] | .Status")

COUNT=0
DESIRED="\"available\""

while [ "$STATUS" != "$DESIRED" ]
do
  echo "    $COUNT: $STATUS --> $DESIRED"
  sleep 5
  COUNT=$(( COUNT+1 ))
  if [ $COUNT -gt 30 ]
  then 
    echo 1>&2 "Volume is still not available after 5 minutes. Aborting."
    exit 20
  fi
  STATUS=$(openstack volume list --name $OS_VOLUME_NAME -f json | jq ".[] | .Status")
done

echo "OS volume created" $OS_VOLUME_ID

# Checking if server flavor is valid
FLAVOR_ID=$(openstack flavor list -f json | jq " .[] | select(.Name==\"$FLAVOR\") | .ID")

if [ -z "$FLAVOR_ID" ]
then
  echo 1>&2 "Flavor $FLAVOR does not exist. Aborting."
  exit 11
fi
echo "Flavor: $FLAVOR_ID"

# Deploying the server
echo "Starting server deployment $(date)"
openstack server create --volume $OS_VOLUME_NAME --flavor $FLAVOR --key-name $KEYPAIR --port $PORT_ID --wait $SERV_NAME> /dev/null 

SERVER_ID=$(openstack server show $SERV_NAME -f json | jq ".id")
echo "Server deployed: " $SERVER_ID
echo "Deployment completed $(date)"

exit 0
