import boto3
import argparse

#Get C9 Instance name to disable auto AWS credentials
parser = argparse.ArgumentParser()
parser.add_argument("--region",
                    help="Region to run python script against, no value assumes default region for AWS CLI.")
parser.add_argument("--c9envname",
                    help="String name of the C9 Instance to report on AWS Managed credentials status")
args = parser.parse_args()

#Print Runtime Diags
if args.region:
    print("Region: Using passed arg region ", args.region)
else :
    print("Region: Using default region fron CLI or ENV Vars")

# Set C9 Client API object
c9 = boto3.client('cloud9')

#Paginate List of Environments to find ours
paginator = c9.get_paginator('list_environments')
pages = paginator.paginate()
for page in pages:
    for obj in page['environmentIds']:
        env_response = c9.describe_environments(
            environmentIds=[
            obj,
        ],)
        env_name = env_response['environments'][0]['name']
        if env_name == args.c9envname:
             target_env_id = env_response['environments'][0]['id']
             target_env_aws_mgd_creds = env_response['environments'][0]['managedCredentialsStatus']
             print("Found ", args.c9envname," environmentid =",target_env_id, " & managedCredentialsStatus = ", target_env_aws_mgd_creds)


try:
    target_env_id
except:
    print("Error: ",args.c9envname, "Not Found")
else:
    if (target_env_id) and (target_env_aws_mgd_creds != 'DISABLED_BY_OWNER'):
        print("DO NOT CREATE CLUSTER,   AWS MANAGED CREDENTIALS ARE STILL SET!!!")
    elif (target_env_id) and (target_env_aws_mgd_creds == 'DISABLED_BY_OWNER'):
        print("SAFE TO CREATE CLUSTER :) ")
    else:
        print("DO NOT CREATE CLUSTER,   AWS MANAGED CREDENTIALS ARE NOT IN A DESIRED STATE")
