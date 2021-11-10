## k8s-opa

#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03/create-cluster-eksctl-existing-vpc-advanced

#### WHEN:
  - I install OPA Gatekeeper onto the cluster
  - I create an OPA template to require pod requests & limits
  - I create an OPA constraint to require pod requests & limits

#### THEN:
  - I will prevent devops teams from creating Pods without requests or limits

#### SO THAT:
  - I can enforce policies

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
cd ~/environment/mglab-share-eks/demos/06/k8s-opa/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: Install OPA Gatekeeper ontot eh cluster.
- Update our kubeconfig to interact with the cluster created in 03/create-cluster-eksctl-existing-vpc-advanced.
```
eksctl utils write-kubeconfig --cluster cluster-eksctl --region $C9_REGION --authenticator-role-arn arn:aws:iam::${C9_AWS_ACCT}:role/cluster-eksctl-creator-role
kubectl config view --minify | grep 'cluster-name' -A 1
kubectl get ns
```
- Install Gatekeeper:
  - [Doc Link](https://open-policy-agent.github.io/gatekeeper/website/docs/install/)
```
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.5/deploy/gatekeeper.yaml
```
- Review the installed CRDs:
```
kubectl get crd | grep gatekeeper
```

#### 2: Create a OPA Template & Constraint to prevent pods without requests & limits.
- Create templates:
```
kubectl apply -f ./artifacts/opa/pod-limits-template.yaml
```
- Create constraints referring to & enforcing the templates:
```
kubectl apply -f ./artifacts/opa/pod-limits-constraint.yaml
```

#### 3: Attempt to create a pod out of policy (without requests & limits).
- Create bad pod:
```
kubectl run opa-demo --image=nginx --port=80 --restart=Never
```
- Create good pod:
```
kubectl run opa-demo --image=nginx --port=80 --restart=Never --limits=cpu=400m,memory=800Mi
```
- Review good pod JSON:
```
kubectl get pod/opa-demo -o json
```

#### 4: Cleanup so that you can run other demos that may not have requests & limits:
```
kubectl delete pod/opa-demo
kubectl delete -f ./artifacts/opa/pod-limits-constraint.yaml
kubectl delete -f ./artifacts/opa/pod-limits-template.yaml
```
---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
kubectl delete -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.5/deploy/gatekeeper.yaml
```
