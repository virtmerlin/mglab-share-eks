## aws-containerinsights-and-prometheus-forwarder

#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl

#### WHEN:
  - I install the kubernetes metrics-server
  - I install the cloudwatch container insights agents with fluentbit
  - I install the cloudwatch prometheus forwarder
  - I enable the EKS cluster control plane logging

#### THEN:
  - I will get the ''/apis/metrics.k8s.io/'' api added to my kubernetes cluster
  - I will get all base metrics from pods & node forwarded to Cloudwatch & to ''/apis/metrics.k8s.io/''
  - I will get all pod & node logs forwarded to Cloudwatch
  - I will get all Control Plane logs forwarded to Cloudwatch
  - I will get all Control Plane Prometheus Metrics forwarded to Cloudwatch

#### SO THAT:
  - I can run kubectl top commands on pods & nodes (metrics-server)
  - I can pass metrics to the k8s HPA & VPA (metrics-server)
  - I can query & visualize metrics for all pods/nodes across my EKS clusters in CloudWatch (container insights agents)
  - I can query & visualize logs for all pods/nodes across my EKS clusters in CloudWatch (fluentbit)
  - I can query & visualize metrics for My EKS Control Plane in CloudWatch (cloudwatch prometheus forwarder)
  - I can query & visualize logs for My EKS Control Plane in CloudWatch (control plane logging)

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
cd ~/environment/mglab-share-eks/demos/05/aws-containerinsights-and-prometheus-forwarder/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Install The Kubernetes Metrics Server.
- Update our kubeconfig to interact with the cluster created in 04-create-advanced-cluster-eksctl-existing-vpc.
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify | grep 'cluster-name' -A 1
kubectl get ns
```
- Explore the raw prometheus formatted metrics in the K8s API server only:
```
kubectl get --raw /metrics
```
- Install K8s metrics-server to aggregate the prometheus formatted metrics across K8s cluster components to a single API endpoint:
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.1/components.yaml
```
- Look at the new 'metrics' node & pod aggregation endpoint:
```
sudo yum install jq -y
kubectl get apiservice v1beta1.metrics.k8s.io -o json | jq '.status'
sleep 3
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
```
- See how kubectl can now fetch metrics from the K8s metrics server, Now we can feed base pod/node metrics to the HPA, VPA, & kubectl:
```
kubectl top nodes
sleep 3
kubectl top pods -A
kubectl get pods -A | grep metrics-server
```

#### 2: Install Container Insights metrics agent & fluent-bit deamon sets on all Nodes.
- Install both the Container Insights metrics & logging agent daemonsets on the nodes:
```
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'cluster-eksctl'/;s/{{region_name}}/'${C9_REGION}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f -
kubectl get ds -n amazon-cloudwatch
```

#### 3: Verify that we can collect metrics & logs on pods
- Verify Metrics via Container Insights Map:
  - Open Console to [link](https://console.aws.amazon.com/cloudwatch/home?#container-insights:infrastructure/map)
  - Select Your Region ... you will see your cluster & metrics widgets

- Verify Logs via Log groups:
  - Open Console to [link](https://console.aws.amazon.com/cloudwatch/home?#logsV2:log-groups/log-group/$252Faws$252Fcontainerinsights$252Fcluster-eksctl$252Fapplication)
  - Select Your Region ... you will see your pod logs

- Verify we can view node/pod Logs/Metrics in Cloud Watch Container Insights:
  - Open Console to [link](https:/console.aws.amazon.com/cloudwatch/home?#logsV2:logs-insights)
    - Click on the 'Select Groups' & select  `/aws/containerinsights/cluster-eksctl/application`
    -  Enter the below query in the Query Box
```
fields @timestamp, kubernetes.pod_name, log
| filter kubernetes.namespace_name="amazon-cloudwatch"
| sort @timestamp desc
```

#### 4: Enable Control Plane logging to CloudWatch.
- Using eksctl to enable all logging:
```
eksctl utils update-cluster-logging --enable-types all --name cluster-eksctl --region $C9_REGION --approve
```
- Verify Logs via Log groups:
  - Open Console to [link](https://console.aws.amazon.com/cloudwatch/home?#logsV2:log-groups/log-group/$252Faws$252Feks$252Fcluster-eksctl$252Fcluster)
  - Select Your Region ... you will see your ctrl plane logs

#### 5: Install the cwagent-prometheus forwarder so it can scrape metrics from the Control Plane and send to CloudWatch
- [DOC LINK:EKS Control Plane Metrics Best Practices]9https://aws.github.io/aws-eks-best-practices/reliability/docs/controlplane.html#monitor-control-plane-metrics)
- Install the cwagent prometheus forwarder:
```
kubectl apply -f ./artifacts/prometheus-eks.yaml
```
- Verify its healthy:
```
kubectl get all -n amazon-cloudwatch
kubectl logs deployment.apps/cwagent-prometheus -n amazon-cloudwatch -f
```
- Verify Control plane Metrics:
  - Open Console to [link](https://console.aws.amazon.com/cloudwatch/home?region=us-west-1#metricsV2:graph)
    - Click on the Source tab and enter data below, change for your region, then 'update':
```
{
    "view": "timeSeries",
    "stacked": false,
    "metrics": [
        [ "ContainerInsights/Prometheus", "apiserver_request_total", "code", "200", "Service", "kubernetes", "ClusterName", "cluster-eksctl" ],
        [ "...", "201", ".", ".", ".", "." ],
        [ ".", "etcd_object_counts", "resource", "deployments.apps", ".", ".", ".", "." ],
        [ "...", "configmaps", ".", ".", ".", "." ],
        [ "...", "endpointslices.discovery.k8s.io", ".", ".", ".", "." ],
        [ "...", "serviceaccounts", ".", ".", ".", "." ],
        [ "...", "secrets", ".", ".", ".", "." ],
        [ "...", "endpoints", ".", ".", ".", "." ],
        [ "...", "replicasets.apps", ".", ".", ".", "." ],
        [ "...", "daemonsets.apps", ".", ".", ".", "." ],
        [ "...", "services", ".", ".", ".", "." ]
    ],
    "region": "us-west-1"
}
```
- Now we can collect Control Plane Prometheus format metrics in Cloud Watch :).

#### 6: (Optional) Install a full Prometheus TSDB in our cluster so we can scrape from the API, Pods, & Nodes within our cluster and query Prometheus directly.
- Install Helm CLI:
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```
- Install Prometheus Chart
```
kubectl create namespace prometheus
helm repo update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus \
        --namespace prometheus \
        --set alertmanager.persistentVolume.storageClass="gp2",server.persistentVolume.storageClass="gp2" \
        --set server.service.type="LoadBalancer" \
        --set server.resources.limits.cpu="1000m" \
        --set server.resources.limits.memory="1024Mi"
```
- Get the deployed ALB for our internal prometheus deployment, you may have to wait 3-5 mins for DNS to register the new LB name:
```
echo "http://"$(kubectl get svc --namespace prometheus prometheus-server \
--output jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```
  -  Open elb address
  -  Sample Graph PromQL(s)
     - {namespace="wordpress-fargate"}
     - count(up{job="kubernetes-apiservers"})
     - sum by (namespace) (kube_pod_info)
     - sum by (namespace) (kube_pod_status_ready{condition="false"})

#### 7: (Optional) Review Fargate Pod Logging
- Fetch the IAM role for our Fargate profile created when the cluster was created:
```
export FARGATE_PROFILE_IAM_ROLE=$(eksctl get fargateprofile --cluster cluster-eksctl | grep fp-wordpress | awk '{print$4}' | awk -F '/' '{print$2}')
echo $FARGATE_PROFILE_IAM_ROLE
```
- Add an IAM policy $FARGATE_PROFILE_IAM_ROLE, that allows the pods to 'put' metrics and logs to Cloudwatch:
```
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy --role-name $FARGATE_PROFILE_IAM_ROLE
```
- Apply/Update the Wordpress Fargate Deployment.  Review the yaml and notice the 'aws-observability' namespace & configmap:
```
cat ../../03/create-cluster-eksctl-existing-vpc-advanced/artifacts/DEMO-k8s-all-in-one-fargate.yaml | sed "s/<REGION>/$C9_REGION/" | kubectl apply -f -
kubectl rollout restart deployment wordpress -n wordpress-fargate
```
```
kubectl get cm -n aws-observability
kubectl get cm -n aws-observability -o yaml
```
- Confirm Pods have restarted & are healthy:
```
kubectl get pods -o wide -n wordpress-fargate
```
- In CloudWatch Console CloudWatch [CloudWatch Logs]->[Log groups]->[fluent-bit-cloudwatch]

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
export FARGATE_PROFILE_IAM_ROLE=$(eksctl get fargateprofile --cluster cluster-eksctl | grep fp-wordpress | awk '{print$4}' | awk -F '/' '{print$2}')
echo $FARGATE_PROFILE_IAM_ROLE
aws iam detach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy --role-name $FARGATE_PROFILE_IAM_ROLE
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
echo $C9_REGION
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
helm delete prometheus prometheus-community/prometheus --namespace prometheus
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'cluster-eksctl'/;s/{{region_name}}/'${C9_REGION}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl delete -f -
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.4.2/components.yaml
```
