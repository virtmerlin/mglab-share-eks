## k8s-run-wordpress-minikube

#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9/C9)
  - A multi-tier web workload (Wordpress) already packaged as docker images

#### WHEN:
  - I install kubectl
  - I start a minikube k8s cluster running on the Cloud9 IDE instance
  - I use the kubectl cli to 'apply' the wordpress workload to minikube

#### THEN:
  - I will get wordpress running locally on a local deployment of kubernetes on the Cloud9 IDE instance

#### SO THAT:
  - I can see a portable way to deploy a k8s workload (same process on dev desktop as will be in cloud)
  - I can debug workload (shell/logs/networking)
  - I can inspect workloads
  - I can learn core K8s resource types
  - I can see how K8s manages persistence
  - I can see how K8s Deployments use K8s ReplicaSets

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES

- 00-setup-cloud9
- 01/docker-build-wordpress

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 0: Reset Cloud9 Instance environ from previous demo(s).
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/01/k8s-run-wordpress-minikube/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Deploy a Kubernetes cluster (minikube) on Cloud9 instance.
- Install minikube CLI & launch K8s cluster:
```
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube start
```
- Install kubectl CLI:
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(<kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

#### 2: Validate the minikube k8s cluster is up.
- Create/Update kubeconfig context for minikube:
```
minikube update-context
```
- Use kubectl to get a list of 'context's:
```
kubectl config get-contexts
```
- Use kubectl to review the cli the newly created minikube 'context':
```
kubectl config view --minify
```
- Show K8s resource types available in K8s as installed by minikube:
```
kubectl api-resources
```

#### 3: Deploy Wordpress into minikube.
- Create K8s namespace(ns):
```
kubectl create ns wordpress
```
- Create K8s configmap(cm) to stash the wordpress database name variable:
```
kubectl create configmap wordpress-config -n wordpress --from-literal=database=wordpress
kubectl get cm wordpress-config -n wordpress -o yaml
```
- Create K8s secret to stash the Wordpress database credential variables:
```
kubectl create secret generic wordpress-db-secret -n wordpress --from-literal=username=myuser --from-literal=password='mypasswd'
kubectl get secret wordpress-db-secret -n wordpress -o jsonpath='{.data.password}' | base64 --decode
kubectl get secret wordpress-db-secret -n wordpress -o jsonpath='{.data.username}' | base64 --decode
```
- Create Mysql [backend] as a K8s ClusterIP Service type:
```
kubectl apply -f ./artifacts/k8s/mysql.yaml -n wordpress
```
- Create Wordpress [frontend] as a K8s Nodeport Service type:
```
kubectl apply -f ./artifacts/k8s/wordpress.yaml -n wordpress
```

#### 4: Expose Wordpress [frontend] running in minikube using the kubectl cli.
- Watch the Pod status until both pods are `running` (_ctrl-c_ to exit):
```
kubectl get pods -n wordpress --watch
```
- Verify Wordpress has started by looking in logs:
```
kubectl logs deployment.apps/wordpress -n wordpress
```
- Map Cloud9 Instance port to the Wordpress Nodeport Service running in minikube so we can test Wordpress on the C9 Instance:
```
kubectl port-forward service/wordpress -n wordpress  9000:80
```
- Open a second Cloud9 IDE terminal window on the C9 instance an `curl` Wordpress:
```
curl http://localhost:9000/wp-admin/install.php
```
   - Close the secondary Terminal and _ctrl-c_ the kubectl PortForward in the original terminal.

#### 5: 'EXEC' into the Wordpress [frontend] to see how a K8s service 'name' is resolved by CoreDNS.
- Inspect the Container's `/etc/resolv.conf`, notice the ip address for default lookups, it will = the minikube kube-dns service ip:
```
kubectl exec -n wordpress --stdin \
--tty $(kubectl get pods -n wordpress | grep -v mysql | grep -v NAME |  awk '{print$1}') \
-- cat /etc/resolv.conf
```
- Update the container's package cache to install dig:
```
kubectl exec -n wordpress --stdin \
--tty $(kubectl get pods -n wordpress | grep -v mysql | grep -v NAME |  awk '{print$1}') \
-- apt-get update
```
- Install IP utils into the running container:
```
kubectl exec -n wordpress --stdin \
--tty $(kubectl get pods -n wordpress | grep -v mysql | grep -v NAME |  awk '{print$1}') \
-- apt-get install iputils-ping dnsutils -y
```
- See what the wordpress-frontend container resolves the wordpress-mysql backend k8s service as:
```
kubectl exec -n wordpress --stdin \
--tty $(kubectl get pods -n wordpress | grep -v mysql | grep -v NAME |  awk '{print$1}') \
-- dig wordpress-mysql.wordpress.svc.cluster.local
```
- Show what minikube (K8s) 'assigned' as Service IP addresses (ClusterIP) for kube-dns & wordpress-mysql, these are the IP addressed CoreDNS has mapped for each K8s service:
```
kubectl get svc -o wide -A
kubectl get svc -o wide -A | grep -E 'wordpress-mysql|kube-dns'
```

#### 6: (Optional) Stateful Sets & PV Data.  See how K8s will dynamically create & map persistentvolumes(pv) to replicas of a statefulsets(sts).
- Show existing persistentvolumes(pv) & persistentvolumeclaims(pvc):
```
kubectl get pv
kubectl get pvc -n wordpress
```
- Create statefulsets(sts):
```
kubectl apply -f ./artifacts/k8s/stateful-set.yaml
kubectl get sts web --watch
```
- Show new persistentvolumes(pv) & persistentvolumeclaims(pvc) matched to replicas:
```
kubectl get pv
kubectl get pvc -A
```

#### 7: (Optional) K8s Deployment Rollout & Rollback.  See the Deployment manage multiple Replicasets updating image & rolling back.
- Update Wordpress deployments to be declared by single yaml:
```
kubectl apply -f ./artifacts/k8s/all-in-one.yaml
kubectl get deployment.v1.apps/wordpress -n wordpress -o yaml | grep image:
```
- Observe the 'rollout' status of the deployment to ensure all containers have started:
```
kubectl rollout status deployment/wordpress -n wordpress
kubectl get deploy wordpress -n wordpress -o wide
kubectl get rs -n wordpress
```
- Update Wordpress frontend deployment to use wordpress image from dockerhub:
```
kubectl -n wordpress --record deployment.apps/wordpress set image wordpress=wordpress
kubectl get deployment.v1.apps/wordpress -n wordpress -o yaml | grep image:
```
- Watch the rollout status, existing containers will be terminated and new ones will start using the new image, this is done by the K8s Deployment controller creating a new ReplicaSet:
```
kubectl rollout status deployment/wordpress -n wordpress
kubectl get rs -n wordpress
```
- Rollback to original deployment ... notice a new k8s replicaset is NOT created but rather an older version is utilized:
```
kubectl -n wordpress rollout history deployment.v1.apps/wordpress
kubectl -n wordpress rollout undo deployment.v1.apps/wordpress --to-revision=1
kubectl get deployment.v1.apps/wordpress -n wordpress -o yaml | grep image:
kubectl get rs -n wordpress
```
#### 8: Minikube stop.
- Stop minikube so it won't drag resources on the Cloud9 IDE instance:
```
minikube stop
```
---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS
- None

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
- Cleanup provided by 00-setup-cloud9
