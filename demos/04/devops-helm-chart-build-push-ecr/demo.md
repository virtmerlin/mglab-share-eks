## devops-helm-chart-build-push-ecr

#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo: 03/create-cluster-eksctl-existing-vpc-advanced
  - A helm chart templates directory prepared for a simple nginx deployment

#### WHEN:
  - I install the helm cli
  - I create an ECR repository
  - I build my helm chart my C9 desktop

#### THEN:
  - I will get a local helm chart
  - I will get an ECR repository

#### SO THAT:
  - I can build a helm chart
  - I can push the helm chart up to ECR (OCI)
  - I can deploy a nginx workload using the helm chart I just pushed up to ECR

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
cd ~/environment/mglab-share-eks/demos/04/devops-helm-chart-build-push-ecr/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Create ECR repository to push helm chart up to.
- [DOC LINK](https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_on_EKS.html#using-helm-charts-eks)

- Create ECR repository to share our image:
```
aws ecr create-repository --repository-name demo-nginx-helm --region $C9_REGION
```

#### 2: Update our kubeconfig to interact with the cluster created in 03-create-advanced-cluster-eksctl-existing-vpc.
- Review your kubeconfig:
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify | grep 'cluster-name' -A 1
kubectl get ns
```

#### 3: Install the helm cli.
- Install helm v3:
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

#### 4: Build Helm Chart & store locally on C9 instance.
- Build Chart:
```
cd ~/environment/mglab-share-eks/demos/04/devops-helm-chart-build-push-ecr/artifacts
helm package demo-nginx-helm
```

#### 5: Push Helm Chart up to ECR.
- Enable OCI support in Helm v3 CLI:
```
export HELM_EXPERIMENTAL_OCI=1
```

- AuthN to ECR and push up Chart:
```
aws ecr get-login-password | helm registry login --username AWS --password-stdin $C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com
```
- Push helm chart up to ECR:
```
helm push demo-nginx-helm-0.1.1.tgz oci://$C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com/
```

#### 6: Deploy Chart from ECR to eks cluster 'cluster-eksctl'.
- Make empty temp local directory to simulate pulling Helm chart from ECR into:
```
mkdir -p ~/environment/blah && cd ~/environment/blah
ls
```
- Pull OCI Helm chart down to local C9 instance into temp local directory:
```
helm pull oci://$C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com/demo-nginx-helm --version 0.1.1
ls -all
tar -xvzf demo-nginx-helm-0.1.1.tgz
```
- Show chart possible values to override:
```
helm show chart demo-nginx-helm
helm show values demo-nginx-helm
```
- Deploy our nginx chart with default values:
```
helm install my-nginx demo-nginx-helm
helm status my-nginx -n default
helm ls -A
```
- Show what the helm Chart created in the cluster:
```
kubectl get deploy -n default -o yaml
```
- Show the passed paramters that were given when deploying the helm chart:
```
helm get values my-nginx -n default
helm get values my-nginx -n default --all
```

#### 7: Update the Deployed Helm Chart.
- Show current image for the deployment:
```
kubectl get deploy my-nginx-demo-nginx-helm -n default -o yaml | grep image
```
- Override chart values for image with public ECR image:
```
helm upgrade \
      --set image.repository=public.ecr.aws/u3e9a9s8/nginx \
      --set image.tag=latest \
      my-nginx ./demo-nginx-helm  -n default
```
- Show updated image for the deployment:
```
kubectl get deploy my-nginx-demo-nginx-helm -n default -o yaml | grep image
```
- See how helm captures state with default secrets backend:
```
kubectl get secret -n default | grep nginx
```
- Use helm cli to 'Rollback' revision:
```
helm history my-nginx -n default
sleep 3
helm rollback my-nginx 1 -n default
```
- Show original image for the deployment:
```
kubectl get deploy my-nginx-demo-nginx-helm -n default -o yaml | grep image
helm history my-nginx -n default
```

#### 8: Interact with well known public Helm Chart Repos.
- Add public repos & Show External Chart Values:
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```
- Search for a chart in a public repo:
```
helm search repo eks
helm search repo eks --version ^1.0.0
```
- Inspect chart in a public repo:
```
helm show values bitnami/wordpress
```
- Pull a well known public chart down to inspect it locally:
```
helm pull bitnami/wordpress
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
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
aws ecr delete-repository --repository-name demo-nginx-helm --region $C9_REGION --force
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
helm delete my-nginx -n default
```
