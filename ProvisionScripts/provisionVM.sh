#!/bin/bash

date

#VM_NAME=child-vm-7
VM_NAME=child-vm-$1
IMAGE_ID=$2
CLUSTER_ID=$3
LOOP=1

KEY=$(cat setup.config | awk '{split($0,a,"="); if(a[1]=="KEY") print a[2]}')
FLAVOR=$(cat setup.config | awk '{split($0,a,"="); if(a[1]=="FLAVOR") print a[2]}')
#IMAGE=$(cat setup.config | awk '{split($0,a,"="); if(a[1]=="IMAGE") print a[2]}')
IMAGE_ID=$(nova image-list | awk '{if (match($4,"ub-doc")) {id=$2}} END{print id}')
KEY_NAME=$(cat setup.config | awk '{split($0,a,"="); if(a[1]=="KEY_NAME") print a[2]}')
SEC_GROUPS=$(cat setup.config | awk '{split($0,a,"="); if(a[1]=="SEC_GROUPS") print a[2]}')
NETWORK=$(cat setup.config | awk '{split($0,a,"="); if(a[1]=="NETWORK") print a[2]}')

echo "created from Image with ID:"
echo $IMAGE_ID
nova boot --flavor $FLAVOR --image $IMAGE_ID --key-name $KEY_NAME --security-groups $SEC_GROUPS --nic net-name=$NETWORK $VM_NAME
 

#sleep 10

while [ $LOOP -gt 0 ]
do
#ip address of instance with inst name
#VM_IP=$(nova show $VM_NAME | awk '{ if(match((if(match($2,"net-work")) print $5 }')
VM_IP=$(nova show $VM_NAME 2>&1| awk '
{split($2,a,":");
if(match(a[2],"vm_state"))
        {state=$4;}
else
        {state=state;};
if(match(state,"active") && match($2,"net-work"))
        {val=$5;}}
END { print val }')

echo $VM_IP

OUT=$(echo $VM_IP | awk '{print $2}')

if [ "$VM_IP" == "" ]; then
	GOAHEAD=0
	
else
	GOAHEAD=1
	LOOP=-1
fi
	echo $LOOP
	echo $GOAHEAD
	echo $OUT
	echo $VM_IP
	sleep 2
done

#sleep 10
if [ $GOAHEAD==1 ]; then
#send image to vm

#scp -o StrictHostKeyChecking=no -i /home/ubuntu/my-key.pem /home/ubuntu/docker-image/ub-py.tar /home/ubuntu/docker-image/configVM.sh ubuntu@$VM_IP:.
ssh -o StrictHostKeyChecking=no -i $KEY -q ubuntu@$VM_IP ./configVM.sh $CLUSTER_ID >/dev/null 2>/dev/null
EXEC=$(echo $?)
echo $EXEC
while [ $EXEC -gt 0 ] 
do
#scp -o StrictHostKeyChecking=no -i /home/ubuntu/my-key.pem /home/ubuntu/docker-image/ub-py.tar /home/ubuntu/docker-image/configVM.sh ubuntu@$VM_IP:.
ssh -o StrictHostKeyChecking=no -i $KEY -q ubuntu@$VM_IP ./configVM.sh $CLUSTER_ID >/dev/null 2>/dev/null
EXEC=$(echo $?)
echo "copy to vm:"$EXEC
sleep 1
done

#avoid strict host key check
#ssh -o StrictHostKeyChecking=no -i /home/ubuntu/my-key.pem ubuntu@$VM_IP "sudo apt-get update"
#ssh -o StrictHostKeyChecking=no -i /home/ubuntu/my-key.pem -q ubuntu@$VM_IP ./configVM.sh $CLUSTER_ID >/dev/null 2>/dev/null
echo "vm config done"

sleep 20
echo "cluster_id"
echo $CLUSTER_ID
echo "new vm IP"
echo $VM_IP
#federate node to swarm
sudo docker -H tcp://$VM_IP:2375 run -d swarm:1.1.1 join --advertise=$VM_IP:2375 --heartbeat=15s --ttl=20s consul://$CLUSTER_ID

echo "node added to swarm"

fi
date
