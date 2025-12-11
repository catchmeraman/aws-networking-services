#!/bin/bash

echo "🦄 Building and deploying Unicorn Website..."

# Set variables
ECR_REPO="114805761158.dkr.ecr.us-east-1.amazonaws.com/unicorn-website"
IMAGE_TAG="unicorn-$(date +%Y%m%d-%H%M%S)"

# Navigate to website directory
cd /Users/ramandeep_chandna/unicorn-website

echo "📦 Building Docker image..."
# Note: This requires Docker to be installed locally
echo "docker build -t unicorn-website:$IMAGE_TAG ."
echo "docker tag unicorn-website:$IMAGE_TAG $ECR_REPO:$IMAGE_TAG"
echo "docker tag unicorn-website:$IMAGE_TAG $ECR_REPO:latest"

echo "🔐 Login to ECR..."
echo "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO"

echo "📤 Push to ECR..."
echo "docker push $ECR_REPO:$IMAGE_TAG"
echo "docker push $ECR_REPO:latest"

echo "🚀 Update Kubernetes deployment..."
echo "kubectl set image deployment/unicorn-website unicorn-website=$ECR_REPO:$IMAGE_TAG"

echo "🔄 Apply updated ingress..."
kubectl apply -f /Users/ramandeep_chandna/kubernetes/unicorn-alb-ingress.yaml

echo "✅ Deployment commands generated!"
echo "📝 Run these commands manually with Docker installed:"
echo "   1. Build: docker build -t unicorn-website:$IMAGE_TAG ."
echo "   2. Tag: docker tag unicorn-website:$IMAGE_TAG $ECR_REPO:$IMAGE_TAG"
echo "   3. Login: aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO"
echo "   4. Push: docker push $ECR_REPO:$IMAGE_TAG"
echo "   5. Deploy: kubectl set image deployment/unicorn-website unicorn-website=$ECR_REPO:$IMAGE_TAG"
