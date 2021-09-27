## 07-aws-lb-controller-ingress
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03-create-advanced-cluster-eksctl-existing-vpc

#### WHEN:
  - I deploy the AWS LoadBalancer Controller

#### THEN:
  - I will deploy a K8s Ingress service in front of a workload

#### SO THAT:
  - I can see how the AWSLB Controller Controller uses an ALB to expose an ingress service

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
cd ~/environment/mglab-share-eks/demos/07-aws-lb-controller-ingress/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Install the AWS Load Balancer Controller.
- [DOC LINK: AWS LB Ctrlr](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)
- Update our kubeconfig to interact with the cluster created in 04-create-advanced-cluster-eksctl-existing-vpc.
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify
kubectl get all -A
```
- Create/Update trust between IAM and the EKS cluster's OIDC provider:
```
eksctl utils associate-iam-oidc-provider  --region $C9_REGION --cluster cluster-eksctl --approve
```
- Create/Update IRSA (IAM Role Service Account) to be used by the load balancer controller:
```
eksctl create iamserviceaccount --region $C9_REGION --cluster=cluster-eksctl --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=arn:aws:iam::$C9_AWS_ACCT:policy/AWSLoadBalancerControllerIAMPolicy --override-existing-serviceaccounts --approve
eksctl get iamserviceaccount --cluster cluster-eksctl --region $C9_REGION
```
- Install CRDs for the AWS LB Controller:
```
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
```
- Install helm v3 cli:
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```
- Install AWS Loadbalancer Controller via Helm Chart:
```
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
      --set clusterName=cluster-eksctl \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller -n kube-system
```
- Verify the controller is running and review the IRSA account annotation:
```
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
```
#### 2: Deploy game2048 using Ingress.
- Deploy and test a patch based routed Ingress Service for 2048 game:
```
kubectl apply -f ./artifacts/DEMO-ingress-app.yaml
sleep 5
kubectl get ingress -n game-2048
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
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl delete -f ./artifacts/DEMO-ingress-app.yaml
helm delete aws-load-balancer-controller -n kube-system
kubectl delete -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
```
