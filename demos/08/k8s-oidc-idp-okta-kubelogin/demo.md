## k8s-oidc-idp-okta-kubelogin

#### GIVEN:
  - A developer desktop with kubectl installed (AWS Cloud9)
  - An EKS cluster created via eksctl from demo 03/create-cluster-eksctl-existing-vpc-advanced


#### WHEN:
  - I setup an OIDC application in a capable Identity provider (IDP)=OKTA
  - I create an OKTA User & Group to simulate onboarding a devops team
  - I configure my EKS cluster to 'trust' tokens signed by that provider

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
- _!!! An OKTA Developer Account !!!_

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 0: Reset Cloud9 Instance environ from previous demo(s).
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/08/k8s-oidc-idp-okta-kubelogin/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
export AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep aws_access_key_id | awk '{print$3}')
export AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep aws_secret_access_key | awk '{print$3}')
clear
echo $C9_REGION
echo $C9_AWS_ACCT
```

#### 1: AS A CLUSTER OPERATOR ---> Create IDP 'Application' using OKTA
- Signup for an OKTA developer account [Here](https://www.okta.com/free-trial/)

- Download & install the okta CLI to create our Application & Add Users:
  - Documentation [Link](https://cli.okta.com/)
```
curl https://raw.githubusercontent.com/okta/okta-cli/master/cli/src/main/scripts/install.sh | bash
```
- Configure the okta cli for your OKTA developer account:
```
okta login
```
- Create OKTA Application:
  - When prompted by the okta CLI, Choose:
    - Keep the suggested Application name [aka just hit enter]
    - Type = Native (3)
    - Sign-In Redirect = http://localhost:8000
    - Sign-Out Redirect = http://localhost:18000
    ```
    okta apps create
    ```
  - Copy the return value of 'okta.oauth2.client-id' into a copy/paste buffer for later steps.

- Set the ISSUER_URL & CLIENT_ID (Audience) shell variables to match the application you just created:
  - _Remove the braces when you paste in the value ..._
```
export CLIENT_ID=[Paste the value of 'okta.oauth2.client-id' from a buffer here]
```
```
export ISSUER_URL=$(okta apps config --app=$CLIENT_ID | grep Issuer | awk '{print$2}')
echo $ISSUER_URL
```
- In the OKTA Console for your Account ... Add a custom claim to your Okta 'default' Authorization Server as well as a Scope for it.  This is required to get group membership claims into the JWT token:
  - https://developer.okta.com/docs/guides/customize-tokens-groups-claim/add-groups-claim-custom-as/
    - Claim:
      - Name:       = okta_groups
      - Value:      = groups: matches regex .*
      - Scopes:     = okta_groups
      - Included:   = Always
    - Scope:
      - Name:                                         = okta_groups
      - Display Name:                                 = okta_groups
      - Description:                                  = pass OIDC groups into token
      - User Consent, Block Services, Default Scope:  = No
      - Metadata Publish:                             = Yes

- In the OKTA Console, create a User & Group:
  - https://developer.okta.com/docs/guides/quickstart/main/#add-a-user-using-the-admin-console
    - User:
      - User First Name   = Fred
      - User Last Name    = Sanford
      - Username          = fred@sanfordarms.com
      - Primary Email     = fred@sanfordarms.com
    - Group:
      - Name              = eks-admins

- In the OKTA Console Add fred@sanfordarms.com to the eks-admins group & assign the application to the group.

#### 2: AS A CLUSTER OPERATOR ---> Configure the EKS cluster's 'OIDC Identity Providers'
- Provide the IDP config to the EKS cluster.  This process will take ~ 10 minutes as it will require the EKS control plane nodes to restart the K8s API.
```
aws eks associate-identity-provider-config \
  --region $C9_REGION \
  --cluster-name cluster-eksctl \
  --oidc identityProviderConfigName="OKTA",issuerUrl="$ISSUER_URL",clientId="$CLIENT_ID",usernameClaim="email",groupsClaim="okta_groups"
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

#### 4: AS A DEVOPS TEAM MEMBER ---> Install kubelogin plugin for kubectl to automate fetching JWT tokens from IDP
- You will execute a number of steps from your own desktop, not Cloud9, in order to see the interaction of kubelogin with OIDC web based AuthN as that flow is blocked by your cloud9 instance.

- Install Krew kubectl cli plugin manager on your desktop (NOT INSIDE OF CLOUD9) :
  - https://github.com/int128/kubelogin#setup
  - MacOS/Linux Instructions provided below
  ```
  (
    set -x; cd "$(mktemp -d)" &&
    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/download/v0.4.1/krew.tar.gz" &&
    tar zxvf krew.tar.gz &&
    KREW=./krew-"${OS}_${ARCH}" &&
    "$KREW" install krew
  )
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
  ```
- Install kubelogin kubectl plugin via Krew on your desktop (NOT INSIDE OF CLOUD9) :
```
kubectl krew install oidc-login
```

#### 5: AS A DEVOPS TEAM MEMBER ---> Fetch a Token, View IT, then use it !!!
- Fetch the ISSUER_URL & CLIENT_ID values from your CLOUD9 to use on your desktop, run these commands in CLOUD9 and then copy/paste the output in your Mac/Linux Bash Prompt on your desktop:
```
echo "export ISSUER_URL=$ISSUER_URL"
echo "export CLIENT_ID=$CLIENT_ID"
```
- Fetch a JWT Token & View it on your desktop (NOT INSIDE OF CLOUD9) :
```
kubectl oidc-login get-token --oidc-issuer-url=$ISSUER_URL \
  --oidc-client-id=$CLIENT_ID  \
  --oidc-extra-scope=profile \
  --oidc-extra-scope=okta_groups \
  --oidc-extra-scope=email --v 1 \
  --listen-address=127.0.0.1:8000
```
- Edit the KubeConfig to create a user named 'oidc' by adding this yaml to your KubeConfig:
```
- name: oidc
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - oidc-login
      - get-token
      - --oidc-issuer-url=[Insert value of $ISSUER_URL here]
      - --oidc-client-id=[Insert value of $CLIENT_ID here]
      - --oidc-extra-scope=profile
      - --oidc-extra-scope=okta_groups
      - --oidc-extra-scope=email
      command: kubectl
      env: null
```
- Send kubectl Request using the user that was just a added to the KubeConfig:
```
rm ~/.kube/cache/oidc-login/*
kubectl get pods -A --user=oidc --v=7
```
- Show Audit Logs in CloudWatch LogInsights Console ... Fred Did it !!!
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
