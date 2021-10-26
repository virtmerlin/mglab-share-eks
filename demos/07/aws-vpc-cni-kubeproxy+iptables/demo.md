## aws-vpc-cni-kubeproxy+iptables

#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03/create-cluster-eksctl-existing-vpc-advanced

#### WHEN:
  - I deploy a simple workload

#### THEN:
  - I will start a remote session onto any EC2 AL2 Docker based node

#### SO THAT:
  - I can see how the kubeproxy uses iptables to load distribute to pods

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES
- 00-setup-cloud9
- 03/create-cluster-eksctl-existing-vpc-advanced

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 0: Reset Cloud9 Instance environ from previous demo(s).
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/07/aws-vpc-cni-kubeproxy+iptables/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Deploy a simple workload.
- Update our kubeconfig to interact with the cluster created in 04-create-advanced-cluster-eksctl-existing-vpc.
```
eksctl utils write-kubeconfig --name cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify | grep 'cluster-name' -A 1
kubectl get ns
```
- Deploy 1 x replica of game-2048:
```
kubectl apply -f ./artifacts/ingress-app.yaml
kubectl get pod -o wide -n game-2048
```
- Make note of the K8s service 'ClusterIP' for the game2048 Nodeport type service:
```
kubectl get svc -n game-2048
```
- Make note of the single replica of game-2048 pod's IPv4 address:
```
export POD_IP=$(kubectl get pod -o wide -n game-2048 | grep deployment-2048 | awk '{print$6}')
echo $POD_IP
```

#### 2: SSH or open SSM Session Manager into any EC2 AL2 Docker based node in the cluster.
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
  chmod 500 ../03/create-cluster-eksctl-existing-vpc-advanced/cluster_eksctl_key.pem
  ssh -i ../03/create-cluster-eksctl-existing-vpc-advanced/cluster_eksctl_key.pem ec2-user@${EC2_NODE}
  ```

#### 3: Within the SSM|SSH remote session, explore kube-proxy & iptables.
- List all iptables PREROUTING tables, notice the table: KUBE-SERVICES:
```
sudo iptables -t nat -L PREROUTING | column -t
```
- List all iptables KUBE-SERVICES tables:
```
sudo iptables -t nat -L KUBE-SERVICES -n  | column -t
```
- Find the target iptable for game-2048, notice the iptables destination IP == the K8s ClusterIP you made note of earlier:
```
sudo iptables -t nat -L KUBE-SERVICES -n  | column -t | grep game-2048/service-2048
```
- Describe its target table, notice the DNAT rule is sending requests targeted to the ClusterIP to the actual Pod IPv4 address you made note of earlier:
```
export GAME2048_TARGET_TABLE=$(sudo iptables -t nat -L KUBE-SERVICES -n  | column -t | grep game-2048/service-2048 | awk '{print$1}')
echo $GAME2048_TARGET_TABLE
sudo iptables -t nat -L $GAME2048_TARGET_TABLE
export GAME2048_POD_TABLE=$(sudo iptables -t nat -L $GAME2048_TARGET_TABLE | grep game-2048/service-2048 | awk '{print$1}')
echo $GAME2048_POD_TABLE
sudo iptables -t nat -L $GAME2048_POD_TABLE
```

#### 4: Open a second Terminal in Cloud9 IDE to scale up game2048.
- [Cloud9 Terminal](https://docs.aws.amazon.com/cloud9/latest/user-guide/tour-ide.html#tour-ide-terminal)
- In a second 'terminal' on the Cloud9 Instance, scale up game 2048 to 5 replicas:
```
kubectl scale deployment deployment-2048 -n game-2048 --replicas=5
```
- Get the K8s Nodeport service 'Port':
```
kubectl get svc -n game-2048
kubectl get svc service-2048 -n game-2048 -o json | jq .spec.ports[].nodePort
```

#### 5: Return to the SSM|SSH remote session on the worker node.
- See what our target table looks like now:
```
sudo iptables -t nat -L $GAME2048_TARGET_TABLE
```
- See how the node/instance listens via nodeport to FWD a NODEPORT -> a CLUSTER_IP... remember this is replicated on EVERY node in the cluster:
```
sudo iptables -t nat -L KUBE-NODEPORTS -n  | column -t
sudo iptables -t nat -L KUBE-NODEPORTS -n  | column -t | grep game-2048/service-2048
export NODEPORT=$(sudo iptables -t nat -L KUBE-NODEPORTS -n  | column -t | grep game-2048/service-2048 | grep -v MASQ | awk -F ':' '{print$2}')
echo $NODEPORT
```
- Lets see what process is actually doing all of this mapping:
```
sudo netstat -ap | grep $NODEPORT
```
---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
kubectl delete -f ./artifacts/ingress-app.yaml
```
