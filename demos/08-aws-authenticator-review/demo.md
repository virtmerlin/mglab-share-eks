## 08-aws-authenticator-review
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03-create-advanced-cluster-eksctl-existing-vpc
  - An AWS CodeBuild project in an AWS CodePipeline has been authorized to deploy a workload

#### WHEN:
  - I install the rbac-lookup plugin via Krew

#### THEN:
  - I will be able to view the mapping of an IAM role to a K8s User (AuthN)
  - I will be able to see the K8s RBAC Bindings (AuthZ)
#### SO THAT:
  - I can see how an external IAM user/role can be Authorized to do things inside of an eks cluster

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES
- 00-setup-cloud9
- 03-create-advanced-cluster-eksctl-existing-vpc
- 04-devops-simple-code-pipeline

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 0: Reset Cloud9 Instance environ from previous demo(s).
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/08-aws-authenticator-review/
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
- Get IAM role used by the AWS CodePipeline/CodeBuild project:
```
export CODEBUILD_IAM_ARN=$(aws cloudformation --region $C9_REGION \
  describe-stacks \
  --stack-name eks-demos-05-devops-simple-code-pipeline \
  --query "Stacks[].Outputs[?OutputKey=='CodeBuildIAMRole'].[OutputValue]" \
  --output text)
echo $CODEBUILD_IAM_ARN
```
- View the AWS IAM Authenticator mapping (AuthN):
```
kubectl get cm aws-auth -o yaml -n kube-system
kubectl get cm aws-auth -o yaml -n kube-system | grep -B 2 -A 1 $CODEBUILD_IAM_ARN
```
- Update/Create namespace & K8s RBAC for the 'codebuild' pipeline user that was built in demo 05-devops-simple-code-pipeline:
```
kubectl apply -f ./artifacts/DEMO-simple-CodePipeline-k8s-RBAC.yaml
```
- View the K8s RBAC bindings given to the mapped 'codebuild' user (AuthZ) using rbac-lookup:
```
kubectl rbac-lookup -o user -o wide
kubectl rbac-lookup codebuild -o wide
```
- View the actual K8s Role & RoleBindings:
```
kubectl get Role/simple-k8s-codepipeline-role -n simple-k8s-codepipeline -o yaml
kubectl get RoleBinding/simple-k8s-codepipeline-admin -n simple-k8s-codepipeline -o yaml
```

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
