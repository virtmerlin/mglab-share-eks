## aws-spot-and-ondemand-nodegroup-with-taints-and-nodeaffinity

#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03/create-cluster-eksctl-existing-vpc-advanced

#### WHEN:
  - I create a self-managed nodegroup with eksctl and launch template customizations
  - I install the node termination handler

#### THEN:
  - I will get a nodegroup with Spot & OnDemand Nodes that will auto AWS tag, K8s label, & K8s taint correctly

#### SO THAT:
  - I can deploy a new workload that will use tolerations and affinity to target the spot nodes

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
cd ~/environment/mglab-share-eks/demos/06/aws-spot-and-ondemand-nodegroup-with-taints-and-nodeaffinity/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Create self managed mixed instance (spot and on_demand billing types) nodegroup with eksctl.
- Update our kubeconfig to interact with the cluster created in 04-create-advanced-cluster-eksctl-existing-vpc.
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify | grep 'cluster-name' -A 1
kubectl get ns
```
- Add Current AWS user mapping to K8s RBAC to system:masters group so that we don't have to assume the cluster creator role for new nodegroup demo:
```
ROLE="    - rolearn: $(aws sts get-caller-identity --query Arn | tr -d '"')\n      username: lab-admin\n      groups:\n        - system:masters"
kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > /tmp/aws-auth-patch.yml
kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"
kubectl get -n kube-system configmap/aws-auth -o yaml
```
- Create Nodegroup:
```
sed  -i "s/\[\[AWSREGION\]\]/$C9_REGION/g" ./artifacts/eks-eksctl-self-managed-nodegroup.yaml
eksctl create nodegroup -f ./artifacts/eks-eksctl-self-managed-nodegroup.yaml
```

#### 2: Deploy workload with tolerations & affinity.
- Show current node labels & taints:
```
kubectl get nodes --label-columns node-lifecycle,eks.amazonaws.com/capacityType,alpha.eksctl.io/nodegroup-name
kubectl get nodes -o json | jq --raw-output '.items[] | .metadata.name,.spec.taints'
```
- Apply nginx yaml with tolerations & affinity, this should have the pod run on a spot tainted node:
```
kubectl apply -f ./artifacts/eks-spot-toleration-nginx.yaml
```
- Show that the Pod 'tolerates' the tain and is required via an affinity rule to run on a Spot node:
```
kubectl get pod spot-nginx -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName -n default
kubectl get nodes --label-columns eks.amazonaws.com/nodegroup,eks.amazonaws.com/capacityType,node-lifecycle
```

#### 3: Install the Node Termination Handler
- Install helm cli:
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```
- Install NTH, just on Linux based Spot Nodes:
```
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-node-termination-handler \
      --namespace kube-system \
      --set enableSpotInterruptionDraining="true" \
      --set enableRebalanceMonitoring="true" \
      --set enableScheduledEventDraining="false" \
      --set linuxNodeSelector.'node-lifecycle'=spot \
      eks/aws-node-termination-handler
```
- View the NTH running as a deamonset on each EC2 node:
```
kubectl get ds -n kube-system
```
---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
eksctl delete nodegroup -f ./artifacts/eks-eksctl-self-managed-nodegroup.yaml --approve
eksctl delete iamidentitymapping --cluster cluster-eksctl --arn $(aws sts get-caller-identity --query Arn | tr -d '"') --all
```
