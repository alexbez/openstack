# Deploy a test server in Open Telekom Cloud (T-Systems)
# Prerequisite: Relevant OpenStack environment variables are already set
#

source ./test-params.sh

# Create VPC router
openstack router create ${MY_ROUTER_NAME}

# Create network
openstack network create ${MY_NETWORK_NAME}

# Create subnet
openstack subnet create --network ${MY_NETWORK_NAME} --subnet-range ${MY_SUBNET_RANGE} --dhcp --dns-nameserver ${OTC_DNS} --dns-nameserver "8.8.8.8" ${MY_SUBNET_NAME}

# Add router to subnet
openstack router add subnet ${MY_ROUTER_NAME} ${MY_SUBNET_NAME}

# Create security group
openstack security group create ${MY_SG_NAME}

# Set security group rules
# -- allow incoming SHH from anywhere
openstack security group rule create ${MY_SG_NAME} --remote-ip 0.0.0.0/0 --protocol tcp --dst-port 22 --ingress

# Create port
openstack port create ${MY_PORT_NAME} --network ${MY_NETWORK_NAME}

# Set security group for the port
openstack port set ${MY_PORT_NAME} --security-group ${MY_SG_NAME}
openstack port show ${MY_PORT_NAME}

# Create floating IP address (EIP)
openstack floating ip create --port ${MY_PORT_NAME} ${OTC_EXTERNAL_NETWORK_ID}

# Create system disk volume
openstack volume create ${MY_SYS_VOLUME_NAME} --size ${MY_SYS_VOLUME_SIZE} --type SATA --availability-zone ${MY_AVAILABILITY_ZONE} --image ${MY_SYS_IMAGE_ID}

# Wait for the system volume to be created
read -p "Press ENTER to continue"
openstack volume show ${MY_SYS_VOLUME_NAME}

# Create SSH keypair
openstack keypair create ${MY_KEYPAIR_NAME} --public-key ${MY_PUBLIC_KEY}

# Deploy server
openstack server create --volume ${MY_SYS_VOLUME_NAME} --flavor ${MY_FLAVOR_NAME} --key-name ${MY_KEYPAIR_NAME} --port ${MY_PORT_NAME} ${MY_SERVER_NAME}

# Wait for the server to be deployed
echo "Wait for the server to be deployed..."
read -p "Press ENTER to continue"

openstack server list

echo ""
echo "*** Done ***"

