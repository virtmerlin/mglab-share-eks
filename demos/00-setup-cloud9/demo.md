## 00-setup-cloud9
#### GIVEN:
  - An AWS Account
  - An IAM user with admin permissions in that account
  - A bash capable mac or pc with the AWS cli installed

#### WHEN:
  - Launch the 2 Cloudformation stacks in the pre-reqs folder

#### THEN:
  - I will get a best practices AWS VPC ready for EKS Clusters that all other demos will use
  - I will get a Cloud9 IDE/Desktop to be used in other demos

#### SO THAT:
  - I can run demos from this repo on the Cloud9 IDE instance

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO SETUP
_This demo is required to run all other demos in this repo._

#### 1: Setup the Cloud9 Desktop

- From your desktop bash capable mac/pc, set the AWS Region variable for where you will want to run these demos (script will default to us-west-1 if no value entered):
```
export C9_REGION=[[YOUR_REGION]] && if [[ $C9_REGION == '[[YOUR_REGION]]' ]];
then export C9_REGION='us-west-1'; fi
```

- From your desktop mac/pc, create/update the VPC using AWS Cloudformation:
```
aws cloudformation deploy --region $C9_REGION --template-file ./pre-reqs/cfn-amazon-eks-vpc-private-subnets.cfn \
    --stack-name eks-demos-networking --tags CLASS=EKS
```

- From your desktop mac/pc, create/update a Cloud9 (C9) instance within the new VPC. You will run all subsequent demo steps after this one from a console on the C9 instance this cloudformation will create:
```
export C9_IAM_SSM=$(aws iam get-instance-profile --instance-profile-name AWSCloud9SSMInstanceProfile --query InstanceProfile.InstanceProfileName | tr -d '"')
if [ "$C9_IAM_SSM" == "AWSCloud9SSMInstanceProfile"  ]; then
  echo "Found Cloud9 SSM Instance Profile ... Skipping CFN"
else
  echo "Cloud9 SSM Instance Profile Does not exist, will create it now ..."
  aws cloudformation deploy --region $C9_REGION --template-file ./pre-reqs/cfn-c9-instance-ssm-role.cfn \
      --stack-name mglab-demos-c9-ssm-instance-role --capabilities CAPABILITY_NAMED_IAM --tags CLASS=ALL
fi
aws cloudformation deploy --region $C9_REGION --template-file ./pre-reqs/cfn-c9-desktop.cfn \
    --stack-name eks-demos-c9-dev-desktop --tags CLASS=EKS
```

- Within the AWS Console of your account, navigate to the C9 instance's 'terminal' window of the IDE & resize the disk.  In this step, you will also pull down this repo into the C9 Instance:
  - Open [https://console.aws.amazon.com/cloud9/home?](https://console.aws.amazon.com/cloud9/home?)
  - Open the created IDE to exec all remaining demo commands from within the new C9 instance's IDE terminal
```
cd ~/environment
git config --global user.name "demo user"
git config --global user.email demo@virtmerlin.io
if [ ! -d mglab-share-archit ]; then git clone https://github.com/virtmerlin/mglab-share-eks.git; fi
chmod 755 ./mglab-share-eks/demos/00-setup-cloud9/pre-reqs/resize.sh
./mglab-share-eks/demos/00-setup-cloud9/pre-reqs/resize.sh
```
- **!!!** **DISABLE** AWS Managed Credentials in the Cloud9 IDE instance **!!!**

    - This is required to use eksctl with a Cloud9 IDE
    - Follow this [Link](https://docs.aws.amazon.com/cloud9/latest/user-guide/how-cloud9-with-iam.html#:~:text=With%20the%20environment%20open%2C%20in,temporary%20credentials%20on%20or%20off.) for Instructions on How
- Run `aws configure` to pass in your AWS IAM User's access key id & secret to use in the Cloud9 IDE instance instead of the AWS managed Credentials you just disabled:

    - Follow this [Link](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-config) for details on the `aws configure` command
```
aws configure
```
- Set Required Key variables for Bash commands to refer to in follow on steps
```
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
echo $C9_REGION
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
echo $C9_AWS_ACCT
```
---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS
- ALL

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
Only run these scripts if you are done cleaning &/or running all dependent demos.

```
aws cloudformation delete-stack --region $C9_REGION --stack-name eks-demos-c9-dev-desktop
aws cloudformation wait stack-delete-complete --region $C9_REGION --stack-name eks-demos-c9-dev-desktop
aws cloudformation delete-stack --region $C9_REGION --stack-name mglab-demos-c9-ssm-instance-role
aws cloudformation wait stack-delete-complete --region $C9_REGION --stack-name mglab-demos-c9-ssm-instance-role
aws cloudformation delete-stack --region $C9_REGION --stack-name eks-demos-networking
aws cloudformation wait stack-delete-complete --region $C9_REGION --stack-name eks-demos-networking
```
