# EKS Unicorn Website Deployment

A complete infrastructure-as-code solution for deploying a containerized web application on Amazon EKS with Application Load Balancer, ACM certificate, and custom domain.

## 🏗️ Architecture

![Architecture Diagram](docs/architecture-diagram.png)

### Components
- **Amazon EKS**: Kubernetes cluster with managed node groups
- **Application Load Balancer**: Internet-facing ALB with SSL termination
- **ACM Certificate**: SSL/TLS certificate for HTTPS
- **Amazon ECR**: Container registry for Docker images
- **Route 53**: DNS management for custom domain

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- Docker installed
- kubectl installed
- Terraform installed (for IaC deployment)
- eksctl installed (for manual deployment)

### Option 1: CloudFormation Deployment (Automated)
```bash
# Deploy EKS cluster
./deploy-to-eks.sh

# Build and push Docker image
./build-and-push.sh
```

### Option 2: Terraform Deployment (Infrastructure as Code)
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## 📁 Repository Structure

```
├── README.md                          # This file
├── ARCHITECTURE.md                    # Detailed architecture documentation
├── DEPLOYMENT-INSTRUCTIONS.md         # Step-by-step deployment guide
├── terraform/                         # Terraform infrastructure code
│   ├── main.tf                       # Provider configuration
│   ├── variables.tf                  # Input variables
│   ├── outputs.tf                    # Output values
│   ├── vpc.tf                        # VPC and networking
│   ├── eks.tf                        # EKS cluster configuration
│   ├── ecr-acm.tf                    # ECR repository and ACM certificate
│   ├── alb-controller.tf             # AWS Load Balancer Controller
│   └── k8s-app.tf                    # Kubernetes application resources
├── kubernetes/                        # Kubernetes manifests
│   ├── unicorn-website-manifest.yaml # Deployment and Service
│   └── unicorn-alb-ingress.yaml      # ALB Ingress
├── unicorn-website/                   # Application source code
│   ├── Dockerfile                    # Container image definition
│   ├── index.html                    # Main website page
│   ├── about.html                    # About page
│   ├── reports.html                  # Reports page
│   ├── cost-report.html              # Cost analysis page
│   └── s3-vectors.html               # S3 vectors page
├── scripts/                           # Deployment scripts
│   ├── build-and-push.sh            # Docker build and push
│   ├── deploy-to-eks.sh              # EKS deployment
│   └── check-cluster-status.sh       # Cluster monitoring
└── docs/                             # Documentation
    └── architecture-diagram.png      # Architecture diagram
```

## 🔧 Configuration

### Environment Variables
```bash
export AWS_REGION=us-east-1
export CLUSTER_NAME=unicorn-cluster
export DOMAIN_NAME=eksawsweek2.cloudopsinsights.com
export ECR_REPOSITORY=114805761158.dkr.ecr.us-east-1.amazonaws.com/unicorn-website
```

### DNS Configuration
Add these DNS records to your domain:

1. **Certificate Validation** (CNAME):
   ```
   Name: _ad4873db31542f02880becbb8127bdcb.eksawsweek2.cloudopsinsights.com
   Value: _65247cbcb2d406267a1fba7f75609fda.xlfgrmvvlj.acm-validations.aws.
   ```

2. **Application Access** (CNAME):
   ```
   Name: eksawsweek2.cloudopsinsights.com
   Value: [ALB-DNS-NAME]
   ```

## 🛠️ Deployment Steps

### 1. Infrastructure Deployment
```bash
# Using CloudFormation (automated)
aws cloudformation create-stack \
  --stack-name eks-unicorn-cluster-stack \
  --template-body file://unicorn-eks-template.yaml \
  --capabilities CAPABILITY_IAM

# Using Terraform (recommended)
cd terraform
terraform init
terraform apply
```

### 2. Application Deployment
```bash
# Build and push Docker image
./scripts/build-and-push.sh

# Deploy to Kubernetes
kubectl apply -f kubernetes/
```

### 3. Verification
```bash
# Check cluster status
kubectl get nodes

# Check application pods
kubectl get pods -l app=unicorn-website

# Check ingress
kubectl get ingress unicorn-website-ingress
```

## 📊 Monitoring & Observability

### CloudWatch Container Insights
```bash
# Enable Container Insights
aws eks update-cluster-config \
  --region us-east-1 \
  --name unicorn-cluster \
  --logging '{"enable":["api","audit","authenticator","controllerManager","scheduler"]}'
```

### Application Metrics
- **CPU Usage**: Monitor pod CPU utilization
- **Memory Usage**: Track memory consumption
- **Request Latency**: ALB target response time
- **Error Rate**: HTTP 4xx/5xx responses

## 🔒 Security Features

- **HTTPS Only**: SSL redirect enforced
- **Private Subnets**: Worker nodes in private subnets
- **Security Groups**: Restricted access rules
- **IAM Roles**: Least privilege access
- **Network Policies**: Pod-to-pod communication control

## 💰 Cost Optimization

- **Spot Instances**: Mixed instance types for cost savings
- **Cluster Autoscaler**: Automatic node scaling
- **Resource Limits**: Prevent resource waste
- **Reserved Instances**: For predictable workloads

## 🚨 Troubleshooting

### Common Issues

1. **Pods not starting**: Check ECR image availability
2. **ALB not created**: Verify AWS Load Balancer Controller
3. **Certificate validation**: Ensure DNS records are added
4. **Access denied**: Check IAM roles and policies

### Debug Commands
```bash
# Check pod logs
kubectl logs -l app=unicorn-website

# Describe pod issues
kubectl describe pod [POD-NAME]

# Check ingress status
kubectl describe ingress unicorn-website-ingress
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## 📞 Support

For issues and questions:
- Create an issue in this repository
- Check the troubleshooting section
- Review AWS EKS documentation
