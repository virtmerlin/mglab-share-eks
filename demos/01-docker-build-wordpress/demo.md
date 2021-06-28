## 01-docker-build-wordpress
#### GIVEN:
  - A developer desktop with docker & git installed (AWS Cloud9)
  - A multi-tier web workload to build (Wordpress)
  - A docker image inspection tool (dive)

#### WHEN:
  - I pull the Dockerhub 'Dockerfile' for Wordpress & build it

#### THEN:
  - I will get a docker image for the Wordpress PHP/Apache front end built

#### SO THAT:
  - I can run it locally on my Cloud9 IDE instance
  - I can debug it (shell/logs/networking)
  - I can inspect it with dive

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#demos)

---------------------------------------------------------------
---------------------------------------------------------------
### REQUIRES
- 00-setup-cloud9

---------------------------------------------------------------
---------------------------------------------------------------
### DEMO

#### 1: Create Wordpress OCI image & inspect it with dive (! If dockerhub limits your pull during build, please login to dockerhub).
- Reset your region & AWS account variables in case you launched a new terminal session:
```
cd ~/environment/mglab-share-eks/demos/01-docker-build-wordpress/
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
echo $C9_REGION
export C9_AWS_ACCT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F '"' '{print$4}')
echo $C9_AWS_ACCT
```
- Clone the public Docker Wordpress git repo and review the 'Dockerfile' you will use to build the OCI image:
```
cd ~/environment
git clone https://github.com/docker-library/wordpress.git
cd wordpress/latest/php7.4/apache/
cat Dockerfile
```
- Create & inspect the Wordpress PHP/Apache front end image:
```
docker build -f Dockerfile . -t eks-demo-wordpress:latest -t eks-demo-wordpress:v1.0
docker images
```
- Now start a container on your Cloud9 IDE using the public 'Dive' tool to view your image layers you just built:
```
docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive:latest eks-demo-wordpress:v1.0
```

#### 2: 'Pull' & start a mysql back-end container from Dockerhub with the docker cli on the Cloud9 Desktop.
- Make directory path so the mysql container can 'persist' data:
```
mkdir -p ~/docker-data
```
- Pull down & start Wordpress Mysql backend on Cloud9 instance:
```
docker run --name crazy-mysql -p 3306:3306 \
-v ~/docker-data:/var/lib/mysql \
-e MYSQL_RANDOM_ROOT_PASSWORD=yes \
-e MYSQL_DATABASE=wordpress \
-e MYSQL_PASSWORD=mypasswd \
-e MYSQL_USER=myuser -d mysql:5.6
```

#### 3: Start Wordpress on Cloud9 instance, see app logs, & exec into pod to debug:
- Start Wordpress frontend you just built on Cloud9 instance:
```
docker run --name crazy-wordpress -p 8181:80 \
-e WORDPRESS_DB_HOST=$(ifconfig eth0 | grep inet | awk -F ':' '{print$2}' | awk '{print$1}' | head -n 1) \
-e WORDPRESS_DB_USER=myuser \
-e WORDPRESS_DB_PASSWORD=mypasswd \
-e WP_HOME='http://localhost:8181' \
-e WP_SITEURL='http://localhost:8181' \
-d eks-demo-wordpress:latest
```
- Look the the Container Logs (use _ctrl-c_ to exit):
```
docker logs crazy-wordpress -f
```
- Start a tty bash session on the running container ... type `exit` to leave the container tty:
```
docker exec -it crazy-wordpress /bin/bash
ps -ef
exit
```
- Test the App is running by curling the container:
```
curl http://localhost:8181/wp-admin/install.php
```
- Now stop both containers:
```
docker ps -a
docker stop crazy-wordpress
docker stop crazy-mysql
```

#### 4: Tag & Push image to an ECR registry that you will create.
- Create/Update ECR repository:
```
aws ecr describe-repositories --repository-names eks-demo-wordpress --region $C9_REGION || aws ecr create-repository --repository-name eks-demo-wordpress --region $C9_REGION
```
- Authenticate to ECR:
```
aws ecr get-login-password --region $C9_REGION | docker login --username AWS --password-stdin $C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com
```
- Tag the Wordpress front end OCI image to set the destination to ECR:
```
docker tag eks-demo-wordpress $C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com/eks-demo-wordpress
docker images
```
- Push the newly tagged Wordpress front end OCI image to ECR, after push is complete look for the repository in the [ECR Console](https://console.aws.amazon.com/ecr/repositories)
```
docker push $C9_AWS_ACCT.dkr.ecr.$C9_REGION.amazonaws.com/eks-demo-wordpress
```

---------------------------------------------------------------
---------------------------------------------------------------
### DEPENDENTS
- None

---------------------------------------------------------------
---------------------------------------------------------------
### CLEANUP
- Do not cleanup if you plan to run any dependent demos
```
export C9_REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document |  grep region | awk -F '"' '{print$4}')
aws ecr delete-repository --region $C9_REGION --repository-name eks-demo-wordpress --force
```
