#!/bin/bash

echo "Deploying Unicorn Website to EKS..."

# Update kubeconfig for the cluster
aws eks update-kubeconfig --region us-east-1 --name unicorn-cluster

# Install AWS Load Balancer Controller (required for ALB Ingress)
echo "Installing AWS Load Balancer Controller..."

# Create service account for AWS Load Balancer Controller
eksctl create iamserviceaccount \
  --cluster=unicorn-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
  --approve

# Install AWS Load Balancer Controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=unicorn-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Wait for controller to be ready
echo "Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=300s

# Deploy the application
echo "Deploying unicorn website..."
kubectl apply -f /Users/ramandeep_chandna/unicorn-website-manifest.yaml

# Deploy the ALB Ingress
echo "Creating ALB Ingress..."
kubectl apply -f /Users/ramandeep_chandna/unicorn-alb-ingress.yaml

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/unicorn-website-deployment

# Get the ALB DNS name
echo "Getting ALB DNS name..."
kubectl get ingress unicorn-website-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

echo ""
echo "Deployment completed!"
echo "Your website will be available at: https://eksawsweek2.cloudopsinsights.com"
echo "Note: You need to create a CNAME record pointing eksawsweek2.cloudopsinsights.com to the ALB DNS name shown above"
