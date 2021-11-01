# Shared Demo Scripts
## Running Containers on AWS EKS

![EKS logo](doc/images/amazon-eks.png)

### What is this?

This repository provides an export of various AWS demonstrations an instructor may leverage to deliver a course about running EKS on AWS.

The demos in this repository are provide as is with **NO WARRANTIES** explicit or implied.  It is the consumers responsibility for costs & management of ANY & ALL provisioned resources in the consumers own AWS account(s) when using these demos.


### Whats in it?

The idea is that a student will create an AWS VPC & Cloud9 instance into their own AWS account, via the AWS Cloudformation templates in this repository.  They will then clone this git repository into that Cloud9 instance to run each of the demos in the repo.

After cloning this repository within the Cloud9 instance, a student can simply `cd` into the relevant demo directory and follow the instructions in the 'demo.md' file.

Here is the folder structure for each demo:

```
     demos/##
          /##/some-demo-description/
                        demo.md
                       /pre-reqs
                       /artifacts
                       /tests
```

- Each demo will be located in its own _demo folder_.
- The folder will be in a sub directory that equals the relevant EKS module, & then another directory called `some-demo-description` that describes the main goals of the demo.
- Within each _demo folder_ there will be:
  - _**a demo.md file**_: A human read-able file that you should be able to follow to repeat/perform a demo.  This is where you will start each demo.
  - _**a pre-reqs folder**_:  (optional) will contain any Infra as Code & scripts that you may need to setup the demo environment for that demo.
  - _**an artifacts folder**_: (optional) will contain any yaml / json/ bins that you may use in running the demo(s).           
  - _**a tests folder**_: (optional) will contain some tests for the automation that will validate a demo is working on a regular schedule and post test results to the README.md.

#### Links

- [Time Table](doc/images/timetable.png)
- [Shared Doc Links](doc/Links.md)

#### Demos
- Class Version: *v1.1*

EKS Module | Demo Name     | Demo Link     | Last Automated Test Timestamp
--- | --- | ---| ---
00| setup-cloud9     | [link](demos/00-setup-cloud9/demo.md)   | Manual 10-18-2021
01| docker-build-wordpress     | [link](demos/01/docker-build-wordpress/demo.md)   | Manual 10-18-2021
01| k8s-run-wordpress-minikube     | [link](demos/01/k8s-run-wordpress-minikube/demo.md)   | Manual 10-18-2021
02| create-cluster-eksctl-one-liner     | [link](demos/02/create-cluster-eksctl-one-liner/demo.md)   | Manual 10-18-2021
03| create-cluster-eksctl-existing-vpc-advanced     | [link](demos/03/create-cluster-eksctl-existing-vpc-advanced/demo.md)   | Manual 10-18-2021
03| create-cluster-terraform     | [link](demos/03/create-cluster-terraform/demo.md)   | Manual 10-18-2021
04| devops-docker-push-ecr     | [link](demos/04/devops-docker-push-ecr/demo.md)   | Manual 10-21-2021
04| devops-helm-chart-build-push-ecr     | [link](demos/04/devops-helm-chart-build-push-ecr/demo.md)   | Manual 10-21-2021
04| devops-simple-code-pipeline     | [link](demos/04/devops-simple-code-pipeline/demo.md)   | Manual 10-21-2021
05| aws-containerinsights-and-prometheus-forwarder     | [link](demos/05/aws-containerinsights-and-prometheus-forwarder/demo.md)   | Manual 10-25-2021
05| k8s-prometheus-and-grafana   | [link](demos/05/k8s-prometheus-and-grafana/demo.md)   | Manual 10-25-2021  
05| k8s-prometheus-and-grafana-AMG    | [link](demos/05/k8s-prometheus-and-grafana-AMG/demo.md)   | Manual 10-25-2021  
05| k8s-cluster-autoscaler     | [link](demos/05/k8s-cluster-autoscaler/demo.md)   | Manual 10-21-2021
06| aws-spot-and-ondemand-nodegroup-with-taints-and-nodeaffinity | [link](demos/06/aws-spot-and-ondemand-nodegroup-with-taints-and-nodeaffinity/demo.md)   | Manual 10-25-2021
07| aws-vpc-cni-pod-ip-assigment | [link](demos/07/aws-vpc-cni-pod-ip-assigment/demo.md)   | Manual 10-25-2021
07| aws-vpc-cni-kubeproxy+iptables | [link](demos/07/aws-vpc-cni-kubeproxy+iptables/demo.md)   | Manual 10-25-2021
07| aws-lb-controller-ingress | [link](demos/07/aws-lb-controller-ingress/demo.md)   | Manual 10-25-2021
07| k8s-servicemesh+tracing-istio-and-jaeger | [link](demos/07/k8s-servicemesh+tracing-istio-and-jaeger/demo.md)   | Manual 10-25-2021
08| aws-iam-authenticator-review | [link](demos/08/aws-iam-authenticator-review/demo.md)   | Manual 10-25-2021
08| aws-irsa-oidc-review | [link](demos/08/aws-irsa-oidc-review/demo.md)   | Manual 10-25-2021
08| k8s-oidc-idp-cognito | [link](demos/08/k8s-oidc-idp-cognito/demo.md)   | Manual 10-31-2021
08| k8s-oidc-idp-okta-kubelogin | [link](demos/08/k8s-oidc-idp-okta-kubelogin/demo.md)   | Manual 10-31-2021
