## k8s-prometheus-and-grafana-AMG

#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03/create-cluster-eksctl-existing-vpc-advanced
  - **WARNING** Running this demo will enable AWS SSO & Organizations in your AWS account

#### WHEN:
  - I create an Amazon Managed Prometheus (AMP) Workspace in us-east-1
  - I create an Amazon Managed Grafana (AMG) Workspace in us-east-1
  - I deploy Prometheus on my ECS cluster to send metrics to AMP Workspace
  - I create a Grafana dashboard on my AMG Workspace

#### THEN:
  - I will be able to visualize my EKS cluster in Grafana using CNCF Tools

#### SO THAT:
  - I can see how to use EKS with CNCF observability tooling

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
cd ~/environment/mglab-share-eks/demos/05/k8s-prometheus-and-grafana-AMG/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Create AWS AMP Workspace.
- Update our kubeconfig to interact with the cluster created in 04-create-advanced-cluster-eksctl-existing-vpc.
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify | grep 'cluster-name' -A 1
kubectl get ns
```
- Create AMP Workspace:
```
aws amp create-workspace --region us-east-1 --alias demo-amp-eks
```
- Setup IAM Pre-Reqs, execute the provided bash script to setup an IAM role for Prometheus (running in our K8s cluster) to forward to AMP:
  - Creates an IAM role with an IAM policy that has permissions to remote-write into an AMP workspace.  Our K8s serviceaccount will 'assume' this role.
```
./artifacts/setup-amp.sh cluster-eksctl
```

#### 2: Install the helm cli to help install the Prometheus Forwarder.
- Install helm v3:
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

#### 3: Install/Update Prometheus Forwarder to 'Remote Write' to the AWS AMP Workspace.
- Use helm to update/install Prometheus
```
export AMP_WSID=$(aws amp list-workspaces --region us-east-1 | jq '.workspaces[] | select (.alias=="demo-amp-eks") | .workspaceId' | tr -d '"')
echo $AMP_WSID
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
if [ "$(helm ls -n prometheus | grep prometheus | awk  '{print$1}')" == "prometheus" ]; then kubectl delete ns prometheus --force; fi
kubectl create ns prometheus
helm install prometheus prometheus-community/prometheus \
     --namespace prometheus \
     -f ./artifacts/prometheus-helm-config.yaml \
     --set serviceAccounts.server.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::$C9_AWS_ACCT:role/EKS-AMP-ServiceAccount-Role" \
     --set serviceAccounts.server.name="iamproxy-service-account" \
     --set server.remoteWrite[0].url="https://aps-workspaces.us-east-1.amazonaws.com/workspaces/$AMP_WSID/api/v1/remote_write" \
     --set server.remoteWrite[0].sigv4.region=us-east-1 \
     --set server.service.type="LoadBalancer" \
     --set server.resources.limits.cpu="1000m" \
     --set server.resources.limits.memory="1024Mi"
```

#### 4: Create AWS AMG Workspace
- Create the IAM Role that will allow AMG to read AMP Workspaces:
```
./artifacts/setup-amg.sh
```

- Create AMG Workspace:
```
aws grafana create-workspace --region us-east-1 \
    --workspace-name demo-amg-eks \
    --account-access-type CURRENT_ACCOUNT \
    --authentication-providers AWS_SSO \
    --permission-type SERVICE_MANAGED \
    --workspace-role-arn arn:aws:iam::$C9_AWS_ACCT:role/EKS-AMG-ServiceAccount-Role \
    --workspace-data-sources PROMETHEUS
```

- In the AMG Console , add a SSO user as 'admin':
  - This step requires that you have AWS SSO Enabled and a user/group registered with SSO so that user/group can be assigned the AMG Workspace.
  - Navigate to :
    - (1) Open the [AMG Console](https://console.aws.amazon.com/grafana/home?region=us-east-1#/workspaces)
    - (2) Click into the 'demo-amg-eks' Workspace
    - (3) Select the 'Authentication' tab
    - (4) Select the 'Assign a new User or Group' button
      - ** You must have already connected as SSO to a supported directory with users & groups **
      - Add the selected user or group as an 'admin' by selecting the 'Make admin' button after the user is added
    - (5) Return to the workspace in the AMG Console and open the 'Grafana Workspace URL' to interact with Grafana
    - (6) When prompted for credentials ... login as the SSO user

- Setup the AMG Grafana workspace to connect to the AMP Workspace as a DataSource:
    - (1) Open the 'Grafana Workspace URL' web UI ...
    - (2) Select the 'AWS Data Sources' menu item in the left menu pane of the Grafana UI (just above the config cog icon)
    - (3) In the Drop Down ... choose Service='Amazon Managed Service for Prometheus'
    - (4) In the next Drop Down, select Region='us-east-1'
    - (5) In the next Drop Down, select Resource Alias='demo-amp-eks'
    - (6) Select button 'Add 1 DataSource'

- Import a K8s Dashboard:
    - (1) In the Grafana web UI ...
    - (2) Select the 'Dashboards' -> 'Manage' menu item in the left menu pane of the Grafana web UI
    - (3) Select the 'Import' button
    - (4) Enter the following value in the 'Import via grafana.com' field = `6417`
    - (5) Select the 'Load' button
    - (6) Select the Prometheus DataSource in the Drop Down
    - (7) Select the 'Import' button

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
export AMP_WSID=$(aws amp list-workspaces --region us-east-1 | jq '.workspaces[] | select (.alias=="demo-amp-eks") | .workspaceId' | tr -d '"')
echo $AMP_WSID
aws amp delete-workspace --region us-east-1 --workspace-id $AMP_WSID
export AMG_WSID=$(aws grafana list-workspaces --region us-east-1 | jq '.workspaces[] | select (.name=="demo-amg-eks") | .id' | tr -d '"')
echo $AMG_WSID
aws grafana delete-workspace --region us-east-1 --workspace-id $AMG_WSID
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
echo $C9_AWS_ACCT
aws iam detach-role-policy --policy-arn arn:aws:iam::$C9_AWS_ACCT:policy/AWSManagedPrometheusWriteAccessPolicy --role-name EKS-AMP-ServiceAccount-Role
aws iam delete-role --role-name EKS-AMP-ServiceAccount-Role
aws iam detach-role-policy --policy-arn arn:aws:iam::$C9_AWS_ACCT:policy/AWSManagedGrafanaDataSourcesPolicy --role-name EKS-AMG-ServiceAccount-Role
aws iam delete-role --role-name EKS-AMG-ServiceAccount-Role
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
echo $C9_REGION
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl delete ns prometheus
```
