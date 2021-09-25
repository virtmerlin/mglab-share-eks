## 04-devops-docker-push-ecr
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 04-create-advanced-cluster-eksctl-existing-vpc
  - A Dockerfile for wordpress php frontend

#### WHEN:
  - I create an ECR repository
  - I build my Wordpress Front End OCI image on my C9 desktop

#### THEN:
  - I will get a local OCI image
  - I will get an ECR repository

#### SO THAT:
  - I can tag the local image and push it up to ECR
  - I can scan the image for CVEs with Clair
  - I can deploy Wordpress using the image I just pushed

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
cd ~/environment/mglab-share-eks/demos/04-devops-docker-push-ecr/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Create ECR repository to push wordpress image up to.
- Create ECR repository to push to & share our image:
```
aws ecr create-repository --repository-name eks-demo-04-devops-docker-push-wordpress-ecr --region $C9_REGION
```

#### 2: Update our kubeconfig to interact with the cluster created in 03-create-advanced-cluster-eksctl-existing-vpc.
- Review your kubeconfig:
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify
kubectl get all -A
```

#### 3:  Git clone a local Dockerfile for Wordpress from virtmerlin repo to build.
- Clone the git repo containing the Dockerfile:
```
cd ~/environment
git clone https://github.com/virtmerlin/mglab-wordpress.git
```

#### 4: Build the OCI image on the local C9 Desktop.
- Build the OCI image:
```
cd ~/environment/mglab-wordpress/Dockerfile
docker build -f Dockerfile . -t eks-demo-wordpress:latest -t eks-demo-wordpress:v1.0
docker images
```

#### 5: Login to ECR private registry
- Get ECR auth token:
```
aws ecr get-login-password --region $C9_REGION | docker login --username AWS --password-stdin $C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com
```

#### 6: Tag & Push the local OCI image to ECR
- Tag & push image to ECR:
```
docker tag eks-demo-wordpress:latest $C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com/eks-demo-04-devops-docker-push-wordpress-ecr:latest
docker push $C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com/eks-demo-04-devops-docker-push-wordpress-ecr:latest
```
- Open the ECR console [link](https://us-west-1.console.aws.amazon.com/ecr/repositories/private/987210092513/eks-demo-05-devops-docker-push-wordpress-ecr?) and scan &/or review your OCI image.

#### 7: Update Wordpress Image in a running deployment.
- Create/Update the wordpress workload deployments & services:
```
cd ~/environment/mglab-share-eks/demos/04-devops-docker-push-ecr
kubectl apply -f ./artifacts/DEMO-k8s-all-in-one-fargate.yaml
kubectl -n wordpress-fargate set image deployment.v1.apps/wordpress wordpress=$C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com/eks-demo-04-devops-docker-push-wordpress-ecr:latest
kubectl -n wordpress-fargate get deployment.v1.apps/wordpress -o yaml | grep image
sleep 3
watch kubectl get pods -o wide -n wordpress-fargate
```
- Test the updated Wordpress Front End Service
```
echo "http://"$(kubectl get svc wordpress -n wordpress-fargate \
--output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
echo $C9_REGION
aws ecr delete-repository --repository-name eks-demo-04-devops-docker-push-wordpress-ecr --region $C9_REGION --force
```
