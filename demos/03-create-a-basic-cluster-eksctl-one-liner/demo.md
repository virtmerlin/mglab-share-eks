## 03-create-a-basic-cluster-eksctl-one-liner
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)

#### WHEN:
  - I install eksctl on the C9 desktop
  - I install kubectl on the C9 desktop
  - I issue an eksctl create cluster 1-liner with a managed nodegroup
  - I issue an eksctl create fargate-profile 1-liner

#### THEN:
  - I will get a VPC for the cluster created for me via cfn
  - I will get all required IAM Roles for EKS created for me via cfn
  - I will get all required security groups for default EKS cluster function created for me via cfn
  - I will get an EKS cluster created for me via cfn
  - I will get a Fargate Profile for my cluster created for me via cfn
  - I will get an Amazon Linux 2 Managed Nodegroup for my cluster created for me via cfn
  - I will get a kubeconfig context generated for me to connect to the new cluster

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES
- 00-setup-cloud9

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 1: Install the eksctl cli onto the Cloud9 IDE instance.
  - [DOC LINK: Installing eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)

- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/03-create-a-basic-cluster-eksctl-one-liner/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
echo $C9_REGION
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
echo $C9_AWS_ACCT
```
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

#### 2: Create Cluster with eksctl.
  - [DOC LINK: Using eksctl](https://eksctl.io/)

- Create Cluster & 1 x Manged NodeGroup with 2 Nodes:
```
eksctl create cluster --name cluster-one-liner \
--enable-ssm \
--region $C9_REGION \
--with-oidc \
--managed --nodes 2 --version 1.20
```
- Create Fargate Profile to attach to the recently created cluster, it will be used to run the Wordpress front-end:
```
eksctl create fargateprofile --name fp-wordpress \
--namespace wordpress-fargate \
--labels "fargate=true" \
--cluster cluster-one-liner \
--region $C9_REGION
```


#### 3: Install kubectl cli and confirm access to the cluster.
- Install/Update kubectl:
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(<kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```
- Use eksctl cli to manually create/update a context to the cluster:
    - the create command should have done this but we are confirming we can do so manually to re-create our `~/.kube/config` file.
```
eksctl utils write-kubeconfig --name cluster-one-liner --region $C9_REGION
kubectl config view --minify
```
- Export your credentials to env vars so that the kubectl wrapper to the aws cli can authN:
```
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
aws sts get-caller-identity
```
- Confirm we can make kubectl calls by getting K8s resources from the cluster:
```
kubectl get all -A
kubectl get nodes -o wide
```

#### 4: Validate k8s dial-tone by deploying Wordpress with the front-end running on Fargate & the Mysql back-end running on the Amazon Linux 2 based Managed Nodegroup.
- Deploy Wordpress with PHP front end to be scheduled on Fargate & mysql backend to be scheduled on the Managed Nodegroup:
  - Exit the watch loop with _ctrl-c_ after all pods are in a running state.

```
kubectl apply -f ./artifacts/03-DEMO-k8s-all-in-one-fargate.yaml
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
- None

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
eksctl delete cluster cluster-one-liner --region $C9_REGION --wait
```
