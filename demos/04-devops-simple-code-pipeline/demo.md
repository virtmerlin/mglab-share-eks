## 04-devops-simple-code-pipeline
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03-create-advanced-cluster-eksctl-existing-vpc
  - Cloud Formation to create my devops environment

#### WHEN:
  - I apply my cloud formation

#### THEN:
  - I will get IAM roles for CodePipeline & CodeBuild
  - I will get an AWS CodeCommit repo with a simple python app & dockerfile in it
  - I will get an AWS CodePipeline pipeline with 2 stages (Source & Build)
  - I will get an AWS CodePipeline stage 1 that triggers off of a commit to my AWS CodeCommit repo
  - I will get an AWS CodePipeline stage 2 that uses an AWS CodeBuild action provider to build and push my OCI image to ECR
  - I will get an AWS CodePipeline stage 2 that uses an AWS CodeBuild action provider to kubectl apply updated images to my EKS cluster

#### SO THAT:
  - I can map my CodeBuild IAM role to a K8s 'codebuild' RBAC user via the IAM Authenticator
  - I can apply a K8s RBAC role to the  K8s 'codebuild' IAM role to allow it to 'kubectl apply' the workload
  - I can demonstrate what happens if something outside of the pipeline alters the simple pipeline app expected state in the EKS Cluster

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES
- 00-setup-cloud9
- 03-create-advanced-cluster-eksctl-existing-vpc

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 0: Reset Cloud9 Instance environ from previous demo(s).
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/04-devops-simple-code-pipeline/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Deploy CodeCommit, ECR, & Code Pipeline/Build projects via Cloud Formation templates.
- Deploy CloudFormation to create pipeline environment:
```
aws cloudformation deploy --region $C9_REGION --template-file ./artifacts/DEMO-simple-CodePipeline-Build.cfn \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides EKSClusterName=cluster-eksctl \
    --stack-name eks-demos-04-devops-simple-code-pipeline \
    --tags CLASS=EKS
```
#### 2: Update our kubeconfig to interact with the cluster created in 03-create-advanced-cluster-eksctl-existing-vpc.
- Review your kubeconfig:
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify
kubectl get all -A
```

#### 3: Setup AuthN & AuthZ with the AWS IAM Authenticator to let the CodeBuild project run a kubectl apply.
- Get IAM role name for Codebuild created by Cloudformation:
```
export CODEBUILD_IAM_ARN=$(aws cloudformation --region $C9_REGION \
    describe-stacks \
    --stack-name eks-demos-04-devops-simple-code-pipeline \
    --query "Stacks[].Outputs[?OutputKey=='CodeBuildIAMRole'].[OutputValue]" \
    --output text)
echo $CODEBUILD_IAM_ARN
```
- Create K8s RBAC Role & Bindings for a K8s RBAC user name 'codebuild' in simple-k8s-codepipeline namespace, this will be mapped to $CODEBUILD_IAM_ARN:
```
kubectl apply -f ./artifacts/DEMO-simple-CodePipeline-k8s-RBAC.yaml
```
- Update the K8s `cm aws-auth -n kube-system` for $CODEBUILD_IAM_ARN to be mapped to the RBAC user called 'codebuild' in K8s:
```
ROLE="    - rolearn: $CODEBUILD_IAM_ARN\n      username: codebuild\n      groups:\n        - codepipeline:codebuild"
kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > /tmp/aws-auth-patch.yml
kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"
kubectl get -n kube-system configmap/aws-auth -o yaml
```

#### 4: Push the simple python App/Dockerfile to CodeCommit & trigger Code Pipeline.
- Setup the git credential helper and clone empty CodeCommit repo into C9 Desktop:
```
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```
- Commit & 'Init' Push to the CodeCommit repo with the sample python application/Dockerfile:
```
cd ~/environment/
git clone https://git-codecommit.us-west-1.amazonaws.com/v1/repos/eks-demo-04-simple-codepipeline-cc
cd ~/environment/eks-demo-04-simple-codepipeline-cc
cp ~/environment/mglab-share-eks/demos/04-devops-simple-code-pipeline/artifacts/simple-app/* ./
git add -A
git commit -am "init"
git push origin
```
-  Open CodePipeline in the Console [link](https://console.aws.amazon.com/codesuite/codepipeline/pipelines), confirm the pipeline runs successfully.

#### 4: Verify simple python app is running and LoadBalancer service is running.  Then 'devops' some changes:
- Check if svc is running, notice that currently we are saying hello to Bubba Bexley:
```
echo "http://"$(kubectl get svc simple-k8s -n simple-k8s-codepipeline \
--output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```
- Edit the Python code to say hello to Fred Sanford Instead [Totally a Sanford & Son ref goin on :)]:
```
sed -i 's/Bubba/Fred/' application.py
git commit -am "Switched Greeting from Bubba to Fred"
git push origin
```
- Check if svc is running, notice that currently we should now be saying hello to Fred:
```
echo "http://"$(kubectl get svc simple-k8s -n simple-k8s-codepipeline \
--output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

#### 5: What happens if?
- Delete the namespace:
```
kubectl delete namespace simple-k8s-codepipeline --force
```
- Can we still access the app?
- Does our K8s RBAC user codebuild still exist?
- Does our K8s RoleBinding allowing codebuild to deploy the App still exist?
- Will the pipeline succeed if we run it again?

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS
- 08-aws-authenticator-review
---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export RM_ARTIFACT_BUCKET=$(aws cloudformation list-stack-resources --region $C9_REGION  --stack-name eks-demos-04-devops-simple-code-pipeline  --query StackResourceSummaries[].PhysicalResourceId | grep artifactbucket | awk -F '"' '{print$2}')
aws s3 rb s3://$RM_ARTIFACT_BUCKET --force
aws ecr delete-repository --region $C9_REGION --repository-name eks-demo-04-simple-codepipeline-ecr --force
aws cloudformation delete-stack --region $C9_REGION  --stack-name eks-demos-04-devops-simple-code-pipeline
aws cloudformation wait stack-delete-complete --region $C9_REGION --stack-name eks-demos-04-devops-simple-code-pipeline
```
