## k8s-oidc-idp-cognito

#### GIVEN:
  - A developer desktop with kubectl installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03/create-cluster-eksctl-existing-vpc-advanced

#### WHEN:
  - I create an AWS Cognito User pool that is OIDC capable as the IDP
  - I create a Cognito User & Group to simulate onboarding a devops team
  - I configure my EKS cluster to trust Cognito as its OIDC IDP

#### THEN:
  - I will be able to bind K8s RBAC roles to users & groups from that IDP

#### SO THAT:
  - I can see how onboard a devops team to EKS without assuming an IAM role.

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
cd ~/environment/mglab-share-eks/demos/08/k8s-oidc-idp-cognito/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: AS A CLUSTER OPERATOR ---> Create OIDC IDP 'Application' using Cognito to AuthN Users & Groups to the K8s cluster
- Deploy CloudFormation to create Cognito UserPool & OIDC Application:
```
aws cloudformation deploy --region $C9_REGION --template-file ./artifacts/cognito-user-pool-cfn.yaml \
    --capabilities CAPABILITY_IAM \
    --stack-name eks-demos-oidc-cognito \
    --tags CLASS=EKS
```
- Collect the following values/outputs from the Cognito Cloudformation Stack, you will use them to create users & fetch OIDC JWT tokens:
  - ISSUER_URL
  ```
  export ISSUER_URL=$(aws cloudformation --region $C9_REGION \
      describe-stacks \
      --stack-name eks-demos-oidc-cognito \
      --query "Stacks[].Outputs[?OutputKey=='IssuerUrl'].[OutputValue]" \
      --output text)
  echo $ISSUER_URL
  ```
  - POOL_ID
  ```
  export POOL_ID=$(aws cloudformation --region $C9_REGION \
      describe-stacks \
      --stack-name eks-demos-oidc-cognito \
      --query "Stacks[].Outputs[?OutputKey=='PoolId'].[OutputValue]" \
      --output text)
  echo $POOL_ID
  ```  
  - CLIENT_ID
  ```
  export CLIENT_ID=$(aws cloudformation --region $C9_REGION \
      describe-stacks \
      --stack-name eks-demos-oidc-cognito \
      --query "Stacks[].Outputs[?OutputKey=='ClientId'].[OutputValue]" \
      --output text)
  echo $CLIENT_ID
  ```
- Create Cognito User fred@sanfordarms.com & hard code his password:
```
aws cognito-idp admin-create-user --user-pool-id $POOL_ID --username fred@sanfordarms.com --temporary-password password
aws cognito-idp admin-set-user-password --user-pool-id $POOL_ID --username fred@sanfordarms.com --password 'Pa$$w0rd' --permanent
```
- Create Cognito Group 'eks-admins' & add Fred to the group:
```
aws cognito-idp create-group --group-name eks-admins --user-pool-id $POOL_ID
aws cognito-idp admin-add-user-to-group --user-pool-id $POOL_ID --username fred@sanfordarms.com --group-name eks-admins
```


#### 2: AS A CLUSTER OPERATOR ---> Configure the EKS cluster's 'OIDC Identity Providers'
- Provide the IDP config to the EKS cluster.  This process will take ~ 10 minutes as it will require the EKS control plane nodes to restart the K8s API.
```
aws eks associate-identity-provider-config \
  --region $C9_REGION \
  --cluster-name cluster-eksctl \
  --oidc identityProviderConfigName="Cognito",issuerUrl="$ISSUER_URL",clientId="$CLIENT_ID",usernameClaim="email",groupsClaim="cognito:groups"
```

#### 3: AS A CLUSTER OPERATOR ---> Create K8s Role & Binding for User
- Show pre-existing K8s admin role to be bound:
```
kubectl get clusterrole cluster-admin -o yaml
```
- Bind the role to a Group from the IDP:
```
kubectl create clusterrolebinding oidc-cluster-admin --clusterrole=cluster-admin --group=eks-admins
```

#### 4: AS A DEVOPS TEAM MEMBER ---> Fetch a Token, View IT, then use it !!!
- Install jq to pretty print json output:
```
sudo yum install jq -y
```
- Fetch a JWT Token from the Cognito IDP & View it:
```
aws cognito-idp admin-initiate-auth --auth-flow ADMIN_USER_PASSWORD_AUTH \
--client-id $CLIENT_ID \
--auth-parameters USERNAME='fred@sanfordarms.com',PASSWORD='Pa$$w0rd' \
--user-pool-id $POOL_ID --query 'AuthenticationResult.IdToken' \
--output text | cut -f 2 -d. | base64 --decode | awk '{print $1"}"}' | jq
```
- Now set the token into a shell variable called JWT_ID_TOKEN:
```
export JWT_ID_TOKEN=$(aws cognito-idp admin-initiate-auth --auth-flow ADMIN_USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID --auth-parameters \
    USERNAME=fred@sanfordarms.com,PASSWORD='Pa$$w0rd' \
  --user-pool-id $POOL_ID \
  --query 'AuthenticationResult.[IdToken]' \
  --o text)
```
- Send kubectl Request using the JWT_ID_TOKEN:
```
kubectl get pods -A --token=$JWT_ID_TOKEN --v=7
```
- Show Audit Logs in CloudWatch LogInsights Console for your cluster ... Fred Did it !!!
  - Open the [CloudWatch LogInsights Console](https://console.aws.amazon.com/cloudwatch/home?#logsV2:logs-insights) ... in the same region as your cluster.
  - Select your cluster's Control Plane Log group to query in the 'Select Log Groups' drop down.
  - Audit Logs must be enabled on the cluster.
```
fields @timestamp, @message
| filter @message like 'fred@sanfordarms.com'
```


---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
```
aws cloudformation delete-stack --region $C9_REGION  --stack-name eks-demos-oidc-cognito
for i in $(aws --region $C9_REGION cognito-idp list-user-pools --max-results 60 | jq '.UserPools[] | select(.Name=="eks-demo-oidc-userpool") | .Id' | tr -d '"');do aws --region $C9_REGION cognito-idp delete-user-pool --user-pool-id $i; done  
```
