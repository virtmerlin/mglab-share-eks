## create-cluster-eksctl-existing-vpc-advanced

#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - A VPC already created with EKS best practices via 00-setup-cloud9 demo

#### WHEN:
  - I install eksctl on the desktop
  - I create a eksctl cluster yaml
  - I create a IAM 'cluster creator' role to create the cluster with
  - I assume the 'cluster creator' role & issue an eksctl create cluster command

#### THEN:
  - I will get all required IAM Roles & security groups created via cfn
  - I will get an EKS cluster using the existing VPC created via cfn
  - I will get an Amazon Linux 2 Managed Nodegroup created via cfn
  - I will get a Fargate Profile created via cfn

#### SO THAT:
  - I can install the K8s Cluster Autoscaler
  - I can run my wordpress application on Fargate & EC2
  - Use this cluster for all other demos that require an EKS cluster

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES
- 00-setup-cloud9

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 0: Reset Cloud9 Instance environ from previous demo(s).
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/03/create-cluster-eksctl-existing-vpc-advanced/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Install the eksctl cli onto the Cloud9 IDE instance.
  - [DOC LINK: Installing eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)

- Download & install the eksctl cli:
```
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
```
- Verify that AWS Managed Temporary Credentials have been disabled.  If not set correctly, please re-visit [DEMO LINK: 00-setup-cloud9](demos/00-setup-cloud9/demo.md) and check steps.
    - If set correctly you will see the following in your response: `SAFE TO CREATE CLUSTER :)`, else the py script will either return _NOT SAFE_ or will fail to run.

```
sudo pip install boto3
export AWS_DEFAULT_REGION=$C9_REGION
python3 ./pre-reqs/check-c9-autocreds.py --region $C9_REGION --c9envname c9-eks-demo-dev-wkstn
```

#### 2: Tag Existing VPC Subnets for the new cluster we are about to create, this is required for the AWS cloud controller &/or AWS Load Balancer Controller to deploy Load Balancers correctly.
- Get EKS VPC Cloudformation Outputs & loop thru subnets to tag them:
```
export SUBNETS_ALL=$(aws cloudformation --region $C9_REGION \
  describe-stacks \
  --stack-name eks-demos-networking \
  --query "Stacks[].Outputs[?OutputKey=='SubnetIds'].[OutputValue]" \
  --output text)
echo $SUBNETS_ALL
```
- Loop through the subnets fetched in the previous step and set the appropriate VPC Subnet tags `kubernetes.io/cluster/[cluster_name],Value=shared`.  The `kubernetes.io/role/[elb|internal-elb]` have already been set via the Cloudformation template that created the VCP.
    - [DOC LINK: VPC Subnet Tagging for EKS](https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/)
    - [CFN TAG LINK: Public](https://github.com/virtmerlin/mglab-share-eks/blob/main/demos/00-setup-cloud9/pre-reqs/cfn-amazon-eks-vpc-private-subnets.cfn#L181-L182)
    - [CFN TAG LINK: Internal](https://github.com/virtmerlin/mglab-share-eks/blob/main/demos/00-setup-cloud9/pre-reqs/cfn-amazon-eks-vpc-private-subnets.cfn#L222-L223)

```
for i in $(echo $SUBNETS_ALL | sed "s/,/ /g")
  do
    aws ec2 create-tags --region $C9_REGION \
        --resources $i --tags Key=kubernetes.io/cluster/cluster-eksctl,Value=shared
    echo "Tagged Subnet $i with Key=kubernetes.io/cluster/cluster-eksctl,Value=shared"
  done
```

#### 3: Create IAM Role to issue the create cluster command with.  This is a best practice to control initial K8s RBAC binding of the system:masters group.
- Create IAM Policy & Role for cluster creator, command may error if the IAM Policy already exists:
     - [DOC LINK: EKS Cluster Creator Role](https://aws.github.io/aws-eks-best-practices/security/docs/iam#create-the-cluster-with-a-dedicated-iam-role)

```
aws iam create-policy --policy-name cluster-eksctl-creator --policy-document file://./artifacts/DEMO-eks-creator-iam-policy-eksctl.json
```
- Edit the json file that defines who IAM 'trusts' to assume the role.   You will inject your AWS account into the file:
```
sed  -i "s/\[\[C9_AWS_ACCT\]\]/$C9_AWS_ACCT/g" ./artifacts/DEMO-eks-creator-iam-policy-trust.json
```
- Create the cluster creator IAM role and attach all required eksctl permissions/policies.
    - [DOC LINK: eksctl Req'd Permissions](https://eksctl.io/usage/minimum-iam-policies/)

```    
aws iam create-role --role-name cluster-eksctl-creator-role --assume-role-policy-document file://./artifacts/DEMO-eks-creator-iam-policy-trust.json
aws iam attach-role-policy --policy-arn arn:aws:iam::${C9_AWS_ACCT}:policy/cluster-eksctl-creator --role-name cluster-eksctl-creator-role
```

#### 4: Prepare to create EKS Cluster with eksctl by updating the cluster.yaml and other requirements.
- Create ec2 Keypair so we can ssh into nodes if we need to, only required if not using SSM:
```
aws ec2 create-key-pair --key-name cluster_eksctl_KeyPair --region $C9_REGION | grep KeyMaterial | awk -F '"' '{print$4}' | sed 's/\\n/\n/g' > cluster_eksctl_key.pem
chmod 700 cluster_eksctl_key.pem
```
- Grab Private Subnet variables from the VPC CFN stack to place into the eksctl cluster yaml:
```
export SUBNET1=$(aws cloudformation --region $C9_REGION \
  describe-stacks \
  --stack-name eks-demos-networking \
  --query "Stacks[].Outputs[?OutputKey=='Subnet1PrivateEKSctlRef'].[OutputValue]" \
  --output text)
echo $SUBNET1
export SUBNET2=$(aws cloudformation --region $C9_REGION \
  describe-stacks \
  --stack-name eks-demos-networking \
  --query "Stacks[].Outputs[?OutputKey=='Subnet2PrivateEKSctlRef'].[OutputValue]" \
  --output text)
echo $SUBNET2
```
- Prepare eksctl cluster yaml with previously set variables for private subnets, aws account, & region:
```
sed  -i "s/\[\[REGION\]\]/$C9_REGION/g" ./artifacts/DEMO-eks-eksctl-cluster.yaml
sed  -i "s/\[\[SUBNET1\]\]/$SUBNET1/g" ./artifacts/DEMO-eks-eksctl-cluster.yaml
sed  -i "s/\[\[SUBNET2\]\]/$SUBNET2/g" ./artifacts/DEMO-eks-eksctl-cluster.yaml
sed  -i "s/\[\[AWSACCT\]\]/$C9_AWS_ACCT/g" ./artifacts/DEMO-eks-eksctl-cluster.yaml
```

- Review the resultant _./artifacts/DEMO-eks-eksctl-cluster.yaml_ file in the Cloud9 text editor.

#### 5: Assume the cluster-eksctl-creator-role IAM role & create the EKS Cluster with eksctl.
- Show current logged in IAM user:
```
aws sts get-caller-identity
aws iam list-roles --query 'Roles[].Arn' | grep cluster-eksctl
```
- Assume IAM role cluster-eksctl-creator-role to create the cluster:
```
export TEMP_ROLE=$(aws sts assume-role --role-arn "arn:aws:iam::$C9_AWS_ACCT:role/cluster-eksctl-creator-role" --role-session-name create-eks --output json)
sudo yum install jq -y
export AWS_ACCESS_KEY_ID=$(echo $TEMP_ROLE | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $TEMP_ROLE | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $TEMP_ROLE | jq -r .Credentials.SessionToken)
aws sts get-caller-identity
```
- As assumed IAM role, create EKS cluster with eksctl into the existing VPC:
```
eksctl create cluster -f ./artifacts/DEMO-eks-eksctl-cluster.yaml
```
- 'UN'-assume IAM role cluster-eksctl-creator-role:
```
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
aws sts get-caller-identity
```

#### 6: Generate a kubeconfig & Access the EKS Cluster with kubectl.
- Install kubectl & review your kubeconfig:
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(<kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```
- Confirm your current IAM user and confirm you are no longer assuming the role:
```
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
aws sts get-caller-identity
```
- Use eksctl cli to manually create/update a context to the cluster, notice the ----authenticator-role-arn argument.  This is what allows us to assume that role for every kubectl command to interact with the K8s API:
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify
```
- Confirm you now have access to run kubectl commands as well as eksctl commands:
```
kubectl get all -A
kubectl get nodes
eksctl get fargateprofile --cluster cluster-eksctl
```

#### 7: Deploy Cluster Autoscaler.
- Fetch the ARN of the IRSA role that eksctl created to install the AWS Cluster Autoscaler with:
```
export CA_SA_ARN=$(eksctl get iamserviceaccount --cluster cluster-eksctl | grep cluster-autoscaler | awk '{print$3}')
echo $CA_SA_ARN
```
- Install the AWS Cluster Autoscaler
```
curl https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml | sed "s/<YOUR.*NAME>/cluster-eksctl/;s/v1.21.0/v1.20.0/" | kubectl apply -f -
kubectl annotate serviceaccount cluster-autoscaler \
    -n kube-system --overwrite \
    eks.amazonaws.com/role-arn=$CA_SA_ARN
kubectl patch deployment cluster-autoscaler \
    -n kube-system \
    -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'
```
- Confirm the Cluster Autoscaler is functional, use _ctrl-c_ to exit:
```
kubectl logs deployment.apps/cluster-autoscaler -n kube-system -f
```


#### 8: Deploy Wordpress with PHP front end on Fargate & Mysql backend on managed Nodegroup.
- Deploy Wordpress front & back end workloads:
```
cat ./artifacts/DEMO-k8s-all-in-one-fargate.yaml  | sed "s/<REGION>/$C9_REGION/" | kubectl apply -f -
watch kubectl get pods -o wide -n wordpress-fargate
```
- Get all K8s nodes, you should see some additional `fargate` nodes:
```
kubectl get nodes -o wide
```
- Get the URL for our new app and test access in your browser:
```
echo "http://"$(kubectl get svc wordpress -n wordpress-fargate \
--output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

- 04*
- 05*
- 06*
- 07*
- 08*


---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl delete namespace wordpress-fargate --force
# Assume Creator role to delete cluster
export TEMP_ROLE=$(aws sts assume-role --role-arn "arn:aws:iam::$C9_AWS_ACCT:role/cluster-eksctl-creator-role" --role-session-name create-eks --output json)
sudo yum install jq -y
export AWS_ACCESS_KEY_ID=$(echo $TEMP_ROLE | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $TEMP_ROLE | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $TEMP_ROLE | jq -r .Credentials.SessionToken)
eksctl delete cluster cluster-eksctl --region $C9_REGION --wait
# Un-Assume Creator role to delete other objects
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
aws ec2 delete-key-pair --key-name cluster_eksctl_KeyPair --region $C9_REGION
aws iam detach-role-policy --policy-arn arn:aws:iam::$C9_AWS_ACCT:policy/cluster-eksctl-creator --role-name cluster-eksctl-creator-role
aws iam delete-policy --policy-arn arn:aws:iam::$C9_AWS_ACCT:policy/cluster-eksctl-creator
aws iam delete-role --role-name cluster-eksctl-creator-role
```
