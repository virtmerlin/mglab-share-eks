# Shared Demo Scripts
## Running Containers on AWS EKS

![EKS logo](doc/images/amazon-eks.png)

### What is this?

This repo provides an export of EKS & kubernetes demonstrations an instructor may leverage to deliver a course about running EKS.

### Whats in it?

The idea is that a student may clone the repo and create an AWS Cloud9 desktop to run each of the demos that may have been seen in a class delivery.

After cloning this repo within the Cloud9 desktop, a student can simply cd into the relevant demo directy and follow the instructions in 'demo.txt'

Here is the folder structure for each demo:

```
     demos /
           /01-somedemo/
                        demo.txt
                       /pre-reqs
                       /artifacts
                       /tests
```

- The Idea is that for each demo there will be a _demo folder_.
- The folder will be named `##-somedemo`
  - with the `##` being ~ to the module in the course to give you an idea where it fits in a story
  - and the `somedemo` being a short description of the actual demo within
- Within each _demo folder_ there will be:
  - _**a demo.txt file**_: A simple txt file that you should be able to follow to repeat/perform a demo.  This is where you will start each demo.
  - _**a pre-reqs folder**_:  will contain some cfn & scripts that you will use to setup the demo environ.
  - _**an artifacts folder**_: will contain demo yaml / json/ bins that you may use in running the demo(s).           
  - _**a tests folder**_: will contain some tests for the automation to validate a demo is working on a regular schedule.

#### Current Demos

[Example EKS Time Table](doc/images/timetable.png)

Demo Name     | Demo Link     | Last Automated Test Timestamp
--- | ---| ---
01-docker-build-wordpress     | ![link](demos/01-docker-build-wordpress/demo.txt)   | Not Yet Automated
02-kubernetes-run-wordpress-minikube     | ![link](demos/02-kubernetes-run-wordpress-minikube/demo.txt)   | Not Yet Automated
03-create-a-basic-cluster-eksctl-one-liner     | ![link](demos/03-create-a-basic-cluster-eksctl-one-liner/demo.txt)   | Not Yet Automated
04-create-advanced-cluster-eksctl-existing-vpc     | ![link](demos/04-create-advanced-cluster-eksctl-existing-vpc/demo.txt)   | Not Yet Automated
04-create-advanced-cluster-aws-cli-existing-vpc     | ![link](demos/04-create-advanced-cluster-aws-cli-existing-vpc/demo.txt)   | Not Yet Automated
05-devops-docker-push-ecr     | ![link](demos/05-devops-docker-push-ecr/demo.txt)   | Not Yet Automated
05-devops-helm-chart-build-push-ecr     | ![link](demos/05-devops-helm-chart-build-push-ecr/demo.txt)   | Not Yet Automated
05-devops-simple-code-pipeline     | ![link](demos/05-devops-simple-code-pipeline/demo.txt)   | Not Yet Automated
06-setup-prometheus-and-container-insights     | ![link](demos/06-setup-prometheus-and-container-insights/demo.txt)   | Not Yet Automated  
06-cluster-autoscaler     | ![link](demos/06-cluster-autoscaler/demo.txt)   | Not Yet Automated
07-spot-n-ondemand-nodegroup-taints-n-affinity | ![link](demos/07-spot-n-ondemand-nodegroup-taints-n-affinity/demo.txt)   | Not Yet Automated
