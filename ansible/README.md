# Define your config file:
Configurations are in the file "config.yml".

# Create your enviroment:

You can crete your inventory manually or using the python script, that will extract the nodes from config.yml:

```bash
python3 create_inventory.py config.yml
```

# If you are using another interface than eth0, you need to edit the templates to use another interface:

Example replacing from eth0 to eth1:
```bash
find -name *.j2 -exec sed -i 's/ansible_eth2/ansible_eth3/g' {} \;
find -name *.j2 -exec sed -i 's/ansible_eth1/ansible_eth2/g' {} \;
find -name *.j2 -exec sed -i 's/ansible_eth0/ansible_eth1/g' {} \;
```

# Start openstack installation:
```bash
time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create.yml 
```

# Once openstack is installed, execute the following steps to validate the installation (connect to the controller node as root):

- Create a private key file:
```bash
ssh-keygen -q -N ""
```

- Create the keypair and security group as demo user
```bash
. demo-openrc
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
openstack keypair list
openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default
```

- Create a provider instance:
```bash
openstack server create --flavor m1.small --image debian_11 \
  --nic net-id=`openstack network show clabext01 -c id | grep " id " | awk '{print $4}'` --security-group default \
  --key-name mykey provider-instance
openstack server list  
openstack console log show provider-instance



# Add this to the vm, to allow access to the vlan 300:
sudo ip link add link virbr2 vlan300 type vlan id 300
sudo ip addr add 172.251.0.1/24 dev vlan300
sudo ip link set vlan300 up
sudo iptables -F

openstack server create --flavor m1.small --image debian_11 \
  --nic net-id=`openstack network show vlan300 -c id | grep " id " | awk '{print $4}'` --security-group default \
  --key-name mykey provider-instance-vlan


```

- Create a self service networ, router and instance:
```bash
openstack network create selfservice
openstack subnet create --network selfservice \
  --dns-nameserver 1.1.1.1 --gateway 172.31.0.1 \
  --subnet-range 172.31.0.0/24 selfservice
 
  
openstack router create router
openstack router add subnet router selfservice
openstack router set router --external-gateway clabext01

openstack server create --flavor m1.small --image debian_11 \
  --nic net-id=`openstack network show selfservice -c id | grep " id " | awk '{print $4}'` --security-group default \
  --key-name mykey selfservice-instance
openstack server list  
openstack console log show selfservice-instance
```

- Create a floating IP and add to self service instance:
```bash
openstack floating ip create clabext01

openstack server add floating ip selfservice-instance `openstack floating ip list -f value -c 'Floating IP Address'`
ssh debian@`openstack floating ip list -f value -c 'Floating IP Address'`
openstack server list  
```

- Test cinder volumes:
```bash
openstack volume create --size 1 volume1
openstack volume create --size 1 volume2
openstack volume list
openstack server add volume provider-instance volume1
openstack server add volume selfservice-instance volume2
openstack volume list
```

- Create a database instance:
```bash
openstack database instance create mysql_instance_1  \
   --flavor `openstack flavor show m1.medium | grep " id " | awk '{print $4}'`  \
   --size 5  \
   --databases test --users user01:passwd01  \
   --datastore mysql \
   --datastore-version 5.7.29   \
   --is-public   \
   --allowed-cidr 0.0.0.0/0   \
   --nic net-id=`openstack network show selfservice -c id | grep " id " | awk '{print $4}'`
```

Wait until database instance is created (Status = HEALTY)
```shell
openstack database instance list
openstack database instance show mysql_instance_1
instance_ip=`openstack database instance show mysql_instance_1 | grep  -oP "(?<={'address':\s')(\d+\.\d+\.\d+\.\d+)(?=',\s'type':\s'public'})"`
mysql -u user01 -ppasswd01 -h ${instance_ip} test
```

Obs.: For troubleshooting, check the instance IP (as trove user) and verify the logs and service status
```bash
systemctl restart guest-agent.service
tail -f /var/log/trove/trove-guestagent.log 
```



- Test heat (orchestration):
```bash

cat << EOF > heat-demo.yml
heat_template_version: 2015-10-15
description: Launch a basic instance with CirrOS image using the
             ``m1.tiny`` flavor, ``mykey`` key,  and one network.

parameters:
  NetID:
    type: string
    description: Network ID to use for the instance.

resources:
  server:
    type: OS::Nova::Server
    properties:
      image: debian_11
      flavor: m1.small
      key_name: mykey
      networks:
      - network: { get_param: NetID }

outputs:
  instance_name:
    description: Name of the instance.
    value: { get_attr: [ server, name ] }
  instance_ip:
    description: IP address of the instance.
    value: { get_attr: [ server, first_address ] }
EOF

export NET_ID=$(openstack network list | awk '/ clabext01 / { print $2 }') && echo $NET_ID
openstack stack create -t heat-demo.yml --parameter "NetID=$NET_ID" stack
openstack stack list
openstack server list
```

- Test zun (container):
```bash
. demo-openrc
openstack network list
export NET_ID=$(openstack network list | awk '/ clabext01 / { print $2 }') && echo ${NET_ID}
openstack appcontainer run --name cirros --net network=$NET_ID cirros ping 8.8.8.8
openstack appcontainer run --name centos7 --net network=$NET_ID centos:7 ping 8.8.8.8
openstack appcontainer list
openstack appcontainer exec --interactive cirros /bin/sh
openstack appcontainer exec --interactive centos7 /bin/sh
```

Clean:
```bash
openstack appcontainer stop container
openstack appcontainer delete container

openstack appcontainer stop centos7
openstack appcontainer delete centos7
```

-  Magnum

[reference](https://www.server-world.info/en/note?os=Ubuntu_20.04&p=openstack_victoria4&f=12)
```bash

openstack network create k8s_int
openstack subnet create --network k8s_int \
  --dns-nameserver 10.5.0.10 --gateway 172.31.0.1 \
  --subnet-range 172.31.0.0/24 k8s_int
  
openstack router create k8s_router
openstack router add subnet k8s_router k8s_int
openstack network set lb --external
openstack router set k8s_router --external-gateway lb

openstack coe cluster template create k8s-cluster-template \
    --image Fedora-CoreOS \
    --external-network lb \
    --fixed-network k8s_int \
    --fixed-subnet k8s_int \
    --dns-nameserver 10.5.0.10 \
    --network-driver flannel \
    --docker-storage-driver overlay2 \
    --docker-volume-size 10 \
    --master-flavor m1.small \
    --flavor m1.small \
    --master-lb-enabled \
    --coe kubernetes 

openstack coe cluster create k8s-cluster \
    --cluster-template k8s-cluster-template \
    --master-count 3 \
    --node-count 3 \
    --keypair mykey

openstack coe cluster list
mkdir -pv ~/tmp/
rm -rf ~/tmp/config
openstack coe cluster config k8s-cluster --dir ~/tmp
export KUBECONFIG=/home/${USER}/tmp/config

kubectl get nodes

 kubectl create deployment test-nginx --image=nginx --replicas=2 
 #kubectl expose deployment test-nginx --type="NodePort" --port 80 
 kubectl expose deployment test-nginx --type="LoadBalancer" --port 80 

# Storageclass for cinder

cat << EOF > cinder.yml
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: EnsureExists
provisioner: kubernetes.io/cinder
EOF

kubectl apply -f cinder.yml

helm repo add bitnami https://charts.bitnami.com/bitnami
helm install mysql bitnami/mysql

```


- Create other images and other instances (Example, debian)

```bash
wget https://cdimage.debian.org/cdimage/openstack/10.9.1-20210423/debian-10.9.1-20210423-openstack-amd64.qcow2

. admin-openrc
openstack image create \
        --container-format bare \
        --disk-format qcow2 \
        --public \
        --file debian-10.9.1-20210423-openstack-amd64.qcow2 \
        debian-10

openstack image list


. demo-openrc

cat << EOF > key.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4tzrayU6ahMhmWuicy+oFfy//9oB+2EdbbmDfA0d+k3SpYjWVqho64/L+sQIAN0RGBJx42GkbKi8B6AriPw8omLOCk2WSYW3ymEC7n3l32M5T4cLr8LIYwoMOBZkMtRc3H62PrHgDoTJLhUOvT2ewj1SLl7iU5gQuInwPE6jWooIb8R6KMUl31qNpkafCVPz5ovw0iYbDamHQF6sq081Xl39px2345T8TofIAocyBUfCOstmAvPaD9lXIV3j9JmPhAy0oweXpxdPiQzBHXepLh/jrvHrV5ggl2iwmLgF3uzwYdFlQN6eCniBtBEcGqEacb6oP2KHfHer04WIbAMHZ eduardoefb@efb
EOF

openstack keypair create --public-key key.pub key

openstack security group rule create --proto icmp default
openstack security group rule create --proto tcp --dst-port 22 default

openstack server create --flavor m1.xlarge --image debian-10 \
  --nic net-id=`openstack network show clabext01 -c id | grep " id " | awk '{print $4}'` --security-group default \
  --key-name key debian-10      

openstack server list  

```


## To create the users and projects after installation:

- Create the file:  users.yml and fill the informations on it (use users_example.xml as reference)
- Encrypt the file using ansible-vault:
```bash
ansible-vault encrypt users.yml
```

- Execute the playbook as below:
```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create_project_and_users.yml --ask-vault-pass
```


### Octavia
```shell
openstack loadbalancer create --name lb01 --vip-subnet-id selfservice 
openstack loadbalancer list
openstack loadbalancer listener create --name listener01 --protocol TCP --protocol-port 22 lb01 
openstack loadbalancer pool create --name pool01 --lb-algorithm ROUND_ROBIN --listener listener01 --protocol TCP 
openstack loadbalancer member create --subnet-id selfservice --address 172.31.0.56 --protocol-port 22 pool01 
openstack floating ip create clabext01 
VIPPORT=$(openstack loadbalancer show lb01 | grep vip_port_id | awk {'print $4'}) 
floating_ip=`openstack floating ip list | grep " None "  | awk '{print $4}'` && echo $floating_ip
openstack floating ip set --port $VIPPORT ${floating_ip}

ssh debian@${floating_ip}


```


Swift:
```shell
. demo-openrc
openstack container create container1
echo "Test" > FILE
openstack object create container1 FILE
rm FILE
openstack object list container1
openstack object save container1 FILE
```