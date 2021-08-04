## 08-aws-irsa-oidc-review
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03-create-advanced-cluster-eksctl-existing-vpc
  - The AWS Load Balancer Controller has been installed using IRSA

#### WHEN:
  - I install the rbac-lookup plugin via Krew

#### THEN:
  - I will be able to view the OIDC mapping of a K8s service account to an IAM Role (outbound IAM AuthN & AuthZ)
  - I will be able to see the K8s RBAC Bindings (internal K8s RBAC AuthZ)

#### SO THAT:
  - I can see how a K8s RBAC sa (service account) can be AuthZ to perform actions on AWS resources.

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES
- 00-setup-cloud9
- 03-create-advanced-cluster-eksctl-existing-vpc
- 07-aws-lb-controller-ingress

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 0: Reset Cloud9 Instance environ from previous demo(s).
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/08-aws-irsa-oidc-review/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Install rbac-lookup utility
- Update our kubeconfig to interact with the cluster created in 04-create-advanced-cluster-eksctl-existing-vpc.
```
eksctl utils write-kubeconfig --name cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify
kubectl get all -A
```
- Install Krew kubectl cli plugin manager on C9 Desktop:
```
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"${OS}_${ARCH}" &&
  "$KREW" install krew
)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
```
- Install rbac-lookup kubectl plugin via Krew:
```
kubectl krew install rbac-lookup
```

#### 2: Review the AWS IAM Authenticator mapping for CodeBuild IAM role
- Get the K8s RBAC service account used by the AWS Loadbalancer Controller:
```
kubectl get deploy aws-load-balancer-controller -n kube-system -o yaml
sleep 3
sudo yum install jq -y
export LB_CTRLR_SA=$(kubectl get deploy aws-load-balancer-controller -n kube-system -o json | jq .spec.template.spec.serviceAccountName | tr -d '"')
echo $LB_CTRLR_SA
```
- View the K8s RBAC sa annotation 'mapping' the sa to assume an external IAM role using the clusters OIDC provider (AuthN):
```
kubectl get sa $LB_CTRLR_SA -o yaml -n kube-system
kubectl get sa $LB_CTRLR_SA -o json -n kube-system | jq .metadata.annotations
```
- View the K8s RBAC bindings given to the mapped to the sa (K8s AuthZ):
```
kubectl rbac-lookup -o user -o wide
kubectl rbac-lookup $LB_CTRLR_SA -o wide
```
- View how IAM trusts the cluster's OIDC provider:
```
export OIDC_URL=$(aws eks describe-cluster --name cluster-eksctl --query 'cluster.identity.oidc.issuer' --region $C9_REGION | tr -d '\"')
echo $OIDC_URL
sleep 3
aws iam list-open-id-connect-providers
```
- View the permissions & conditions of the IAM role that the sa will assume:
```
export IAM_ROLE=$(kubectl get sa $LB_CTRLR_SA -o json -n kube-system | jq .metadata.annotations | grep role | awk -F'"' '{print$4}' | awk -F '/' '{print$2}' )
echo $IAM_ROLE
aws iam get-role --role-name $IAM_ROLE | jq .Role.AssumeRolePolicyDocument.Statement
```
- Use [IAM Console](https://console.aws.amazon.com/iam/home#/home) to review the IAM policies & trusts attached to that role.

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
