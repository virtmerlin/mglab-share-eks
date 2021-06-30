## 08-aws-vpc-cni-pod-ip-assigment
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 04-create-advanced-cluster-eksctl-existing-vpc

#### WHEN:
  - I deploy a simple workload

#### THEN:
  - I will start a remote session onto any EC2 AL2 Docker based node

#### SO THAT:
  - I can see how the AWS VCP CNI sets up Pod IP assignment

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES
- 00-setup-cloud9
- 04-create-advanced-cluster-eksctl-existing-vpc

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 1: Deploy a simple workload.
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/08-aws-vpc-cni-kubeproxy+iptables
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
echo $C9_REGION
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
echo $C9_AWS_ACCT
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
```
- Update our kubeconfig to interact with the cluster created in 04-create-advanced-cluster-eksctl-existing-vpc.
```
eksctl utils write-kubeconfig --name cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify
kubectl get all -A
```
- Deploy 1 x replica of game-2048:
```
kubectl apply -f ./artifacts/08-DEMO-ingress-app.yaml
kubectl get pod -o wide -n game-2048
```
- Make note of the single replica of game-2048 pod's IPv4 address:
```
export POD_IP=$(kubectl get pod -o wide -n game-2048 | grep deployment-2048 | awk '{print$6}')
echo $POD_IP
```
#### 2: SSH or open SSM Session Manager into the EC2 AL2 Docker based node in the cluster running the pod.
- [SSM Starting a Session via SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html)
- Its a FAR better practice to use SSM Session Manager, if SSM is functional in your account, please open a SSM Session to any EC2 host, but if SSM is not enabled in your account you can use the following steps to SSH.
  - Get the host private ip that game-2048 is running on:
  ```
  export EC2_NODE=$(kubectl get pod -o wide -n game-2048 | grep deployment-2048 | awk '{print$7}' | tr '-' '\.' | awk -F '.' '{print$2"."$3"."$4"."$5}')
  echo $EC2_NODE
  ```
  - Allow SSH from the Cloud9 desktop to the SG for the nodegroups:
  ```
  export C9_IP=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .privateIp | tr -d '"')
  echo $C9_IP
  export EC2_SGS=$(aws ec2 describe-network-interfaces --filters Name=addresses.private-ip-address,Values=${EC2_NODE} --query NetworkInterfaces[].Groups[].GroupId)
  echo $EC2_SGS
  echo $EC2_SGS | jq -c '.[]' | while read i; do
    echo "Setting Rule to allow SSH in for nodes in $i from C9 instance"
    SG=$(echo $i | tr -d '"')
    aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 22 --cidr ${C9_IP}/32
  done
  ```
  - SSH into instance, all remaining remote session commands after this one will occur on the EC2 AL2 Docker based node (in either SSH or SSM Session manager remote session):
  ```
  chmod 500 ../04-create-advanced-cluster-eksctl-existing-vpc/cluster_eksctl_key.pem
  ssh -i ../04-create-advanced-cluster-eksctl-existing-vpc/cluster_eksctl_key.pem ec2-user@${EC2_NODE}
  ```

#### 3: Within the SSM|SSH remote session, see how the IP address is assigned by the AWS VPC CNI default settings.
- Get the container ids of a workload you want to inspect.  You should see also pause container for every pod running on the node:
```
sudo su
docker ps -a | grep 2048
sleep 3
export CTR_ID=$(docker ps -a | grep docker-2048 | awk '{print$1}')
export CTR_ID_PAUSE=$(docker ps -a | grep 2048 | grep pause | awk '{print$1}')
echo $CTR_ID
echo $CTR_ID_PAUSE
```
- Now get the pod veth(A) ID mapped using the app container:
```
docker exec -it $CTR_ID ash -c 'cat /sys/class/net/eth0/iflink'
```
```
docker exec -it $CTR_ID ash -c 'cat /sys/class/net/eth0/iflink' > /tmp/mycntreni.value
```
```
export CTR_VETH_POD=$(cat /tmp/mycntreni.value)
echo $CTR_VETH_POD
```
- Now get the host namespace veth(B) 'linked' to the pod network namespace using that veth(A) pod ID from the container:
```
grep -l [[ INSERT VAL OF $CTR_VETH_POD HERE ]] /sys/class/net/*/ifindex
export CTR_VETH_NODE=$(grep -l 8 /sys/class/net/*/ifindex | awk -F '/' '{print$5}')
echo $CTR_VETH_NODE
```
- You can see this link via the ip link list command, notice it has its own network names space id for the 2 linked veths:
```
ip link list | grep $CTR_VETH_NODE
```
- Now lets look at how those veths route in the host to get/in out:
  - Get IP of Pod using pause container ID:
  ```
  CMD="curl -s http://localhost:61679/v1/enis | jq '.ENIs[].IPv4Addresses[] | select(.IPAMKey.containerID|startswith(\"$CTR_ID_PAUSE\")) | .Address'"
  export CTR_IP=$(eval $CMD | tr -d '"')
  echo $CTR_IP
  ```
  - Get inbound/outbound rules from host for that pod:
  ```
  ip rule list | grep $CTR_IP
  ```
  - Get the Inbound route for traffic coming into the pod, we can see the route table send all traffic in for the pod to our veth :)
  ```
  ip route show table main | grep $CTR_IP
  echo $CTR_VETH_NODE
  ```
---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
