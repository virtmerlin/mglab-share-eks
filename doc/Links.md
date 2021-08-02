## Doc Links

#### [Return to Main Readme](https://github.com/virtmerlin/mglab-share-eks#links)

#### (1) Container & Kubernetes Fundamentals

- [Docker File Reference](https://docs.docker.com/engine/reference/builder/)
- [K8s Supported Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
- [Container Runtimes versus Container optimized VMMs](https://www.inovex.de/blog/containers-docker-containerd-nabla-kata-firecracker/)
- [OCI](https://opencontainers.org/)
- [The 12 factor App](https://12factor.net/)
- [The 1 Factor App](https://tanzu.vmware.com/content/blog/1-factor-app-kubernetes-modernization)
- [The Open Source Dive Tool](https://github.com/wagoodman/dive)

- [CNCF Landscape](https://landscape.cncf.io/)
- [K8s Latest Release Information](https://www.kubernetes.dev/resources/release/)
- [K8s CLI CheatSheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubectl One Liners](https://gist.github.com/mikejoh/449c50058bbded6c1634b66f45accff3)
- [K8s API Ref Docs](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.20/#-strong-api-groups-strong-)
- [K8s Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [K8s Replicaset](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)
- [K8s Storage Class](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [K8s Node Specific Volume Limits](https://kubernetes.io/docs/concepts/storage/storage-limits/)
- [K8s Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [K8s Scheduler](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
- [K8s Assign Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [K8s Well Known labels & Taints](https://kubernetes.io/docs/reference/kubernetes-api/labels-annotations-taints/)
- [K8s Liveness Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [AWS EFS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)
- [AWS EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [AWS FSx Lustre CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/fsx-csi.html)

#### (2) EKS Fundamentals
- [Public AWS EKS Ref Customers](https://aws.amazon.com/eks/customers/)
- [EKS Video Blogcast 'Containers From The Couch'](https://containersfromthecouch.com/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [EKS Public Roadmap](https://github.com/aws/containers-roadmap)
- [EKS Optimized AMIs](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-amis.html)
- [EKCTL the Official CLI for EKS](https://eksctl.io/)

#### (3) Building an EKS Cluster
- [GITHUB: AWS IAM Authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator)
- [AWS EKS Identity Based Policy Examples](https://docs.aws.amazon.com/eks/latest/userguide/security_iam_id-based-policy-examples.html)
- [Create EKS Kubeconfig](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)
- [AWS K8s Cluster Autoscaler](https://docs.aws.amazon.com/eks/latest/userguide/cluster-autoscaler.html)
- [AWS CDK Create EKS Cluster](https://cdk-eks-devops.workshop.aws/en/40-deploy-clusters/200-cluster/210-cluster.html)

#### (4) Deploying Apps to your EKS Cluster
- [CI/CD EKS Workshop w/ ArgoCD](https://www.eksworkshop.com/intermediate/290_argocd/)
- [CI/CD EKS Workshop w/ FluzCD](https://www.eksworkshop.com/intermediate/260_weave_flux/installweaveflux/)
- [CI/CD with EKS & Spinnaker](https://aws.amazon.com/blogs/opensource/continuous-delivery-spinnaker-amazon-eks/)
- [Push an OCI Helm Chart to ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/push-oci-artifact.html)
- [CDK8s](https://cdk8s.io/)
- [CDK8s Get Started](https://cdk8s.io/docs/latest/getting-started)
- [CDK8s Github Repo](https://github.com/awslabs/cdk8s)

#### (5) Observability with EKS
- [K8s monitoring Tools](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-usage-monitoring/)
- [K8s Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [K8s Custom Metrics](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/instrumentation/custom-metrics-api.md)
- [EKS Control Plane Metrics w/ Prometheus](https://docs.aws.amazon.com/eks/latest/userguide/prometheus.html)
- [EKS Workshop w/ Prometheus](https://www.eksworkshop.com/intermediate/240_monitoring/deploy-prometheus/)
- [EKS & Amazon Managed Prometheus](https://aws.amazon.com/blogs/mt/getting-started-amazon-managed-service-for-prometheus/)
- [3rd Party Blog: Cluster Autoscaler, VPA, HPA Best practices](https://www.replex.io/blog/kubernetes-in-production-best-practices-for-cluster-autoscaler-hpa-and-vpa)
- [AWS Node Termination Handler](https://github.com/aws/aws-node-termination-handler)
- [EKS Workshop w/ xRay](https://www.eksworkshop.com/intermediate/245_x-ray/)
- Istio/Jaeger Sample App we used in Class Demo:
  - https://istio.io/latest/docs/examples/bookinfo/
  - https://istio.io/latest/docs/examples/microservices-istio/logs-istio/
  - https://istio.io/latest/docs/tasks/observability/distributed-tracing/jaeger/

#### (6) Efficient & Well Architected clusters
- [Proportional Autoscaler](https://github.com/kubernetes-sigs/cluster-proportional-autoscaler)
- [EKS pricing](https://aws.amazon.com/eks/pricing/)
- [Max Pods per ENI by instance type](https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt)
- [Spot Instance Advisor](https://aws.amazon.com/ec2/spot/instance-advisor/)
- [EKS Best Practices Github Repo](https://aws.github.io/aws-eks-best-practices/)
- Fargate & EKS:
  - https://docs.aws.amazon.com/eks/latest/userguide/fargate.html
  - https://aws.amazon.com/blogs/aws/new-aws-fargate-for-amazon-eks-now-supports-amazon-efs/
- Firecracker:
  - https://firecracker-microvm.github.io/

#### (7) EKS Networking
- AWS VPC CNI
  - https://github.com/aws/amazon-vpc-cni-k8s/
- Using custom CNI's with EKS:
  - https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network.html
- Istio on EKS:
  - https://aws.amazon.com/blogs/opensource/getting-started-istio-eks/
- Layer 7 Application Load Balancing on EKS:
  - https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
  - https://aws.amazon.com/premiumsupport/knowledge-center/eks-alb-ingress-controller-setup/
  - https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller
- [EKS & AppMesh](https://www.eksworkshop.com/advanced/330_servicemesh_using_appmesh/)
- [EKS Jazz AppMesh Workload Blog](https://aws.amazon.com/blogs/compute/learning-aws-app-mesh/)

#### (8/9) EKS AuthZ, AuthN, & Security Best Practices
- [EKS BestPractices: Security](https://aws.github.io/aws-eks-best-practices/security/docs/index.html)
- EKS CIS benchmarks:
  - https://aws.amazon.com/blogs/containers/introducing-cis-amazon-eks-benchmark/
- EKS Cluster Authentication:
  - https://docs.aws.amazon.com/eks/latest/userguide/managing-auth.html
  - [New: Bring Your own IDP](https://aws.amazon.com/blogs/containers/introducing-oidc-identity-provider-authentication-amazon-eks/)
- IAM roles & K8s Service Accounts:
  - https://aws.amazon.com/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/
  - https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- Docker image multi stage builds:
  - https://docs.docker.com/develop/develop-images/multistage-build/
- Calico on EKS w VPC CNI:
  - https://docs.aws.amazon.com/eks/latest/userguide/calico.html
- AWS Security Groups for Pods:
  - https://aws.amazon.com/blogs/containers/introducing-security-groups-for-pods/
  - https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html

#### (10) Upgrading EKS Clusters
- K8s Cross Version Dependencies:
  - https://kubernetes.io/docs/setup/release/version-skew-policy/
- EKS K8s & Platform Versions:
  - https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
  - https://docs.aws.amazon.com/eks/latest/userguide/platform-versions.html
- EKS Reading of The 'Fine' Manuals for Upgrades:
  - https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
  - https://docs.aws.amazon.com/eks/latest/userguide/update-managed-node-group.html
  - https://docs.aws.amazon.com/eks/latest/userguide/update-workers.html
  - https://kubernetes.io/docs/tasks/administer-cluster/cluster-management/
