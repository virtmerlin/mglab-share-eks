## 05-cluster-autoscaler
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster named 'cluster-eksctl' has been created via 03-create-advanced-cluster-eksctl-existing-vpc

#### WHEN:
  - I validate the cluster autoscaler is functioning

#### THEN:
  - I will create a simple deployment
  - I will validate the NodeGroups ASG min/max settings
  - I will scale the deployment
#### SO THAT:
  - I can see the cluster add nodes when necessary

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
cd ~/environment/mglab-share-eks/demos/05-cluster-autoscaler/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Deploy & Verify the Cluster Autoscaler.
- Update our kubeconfig to interact with the cluster created in 04-create-advanced-cluster-eksctl-existing-vpc.
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify
kubectl get all -A
```

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
- Get cluster cluster-autoscaler service account & review IAM Role IRSA Mappings:
```
kubectl get sa cluster-autoscaler -n kube-system -o yaml
kubectl get sa cluster-autoscaler -n kube-system -o yaml | grep "eks.amazonaws.com/role-arn"
```
- Get the Cluster Autoscaler Deployment and review that the '_cluster-autoscaler_' K8s service account is being leveraged by the deployment:
```
kubectl get deployment cluster-autoscaler -n kube-system -o yaml
kubectl get deployment cluster-autoscaler -n kube-system -o yaml | grep "serviceAccount:"
```
- List the EKS Clusters private OIDC provider that is _trusted_ to sign IRSA tokens so the K8s SA can assume the IAM Role:
```
export OIDC_URL=$(aws eks describe-cluster --name cluster-eksctl --query 'cluster.identity.oidc.issuer' --region $C9_REGION | tr -d '\"')
echo $OIDC_URL
aws iam list-open-id-connect-providers
```
#### 2: Create & Scale deployment to witness the CA scale EC2 instances up/down.
- Count Current EC2 Nodes:
```
kubectl get nodes -o wide | grep -v fargate
```
- Create a new K8s deployment scaled to 0:
```
kubectl create deployment autoscaler-demo --image=public.ecr.aws/u3e9a9s8/nginx:latest
kubectl set resources deploy autoscaler-demo --requests=cpu=200m,memory=200Mi
```
- Scale deployment UP:
```
kubectl scale deployment autoscaler-demo --replicas=50
```
- Watch cluster autoscale log events, _ctrl-c_ to exit:
```
kubectl logs deployment.apps/cluster-autoscaler -n kube-system -f
```
- Watch pod scale up as nodes are added, _ctrl-c_ to exit:
```
kubectl get deployment autoscaler-demo --watch
```
- Confirm nodes have scaled up:
```
kubectl get nodes -o wide
```
- Scale deployment DOWN, it will take considerably longer for the CA to scale nodes down:
```
kubectl delete deployment autoscaler-demo
kubectl get nodes -o wide
```

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
