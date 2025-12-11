#!/bin/bash

# Build and push unicorn website to ECR
cd /Users/ramandeep_chandna/unicorn-website

# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 114805761158.dkr.ecr.us-east-1.amazonaws.com

# Build the Docker image
docker build -t unicorn-website .

# Tag the image
docker tag unicorn-website:latest 114805761158.dkr.ecr.us-east-1.amazonaws.com/unicorn-website:latest

# Push the image
docker push 114805761158.dkr.ecr.us-east-1.amazonaws.com/unicorn-website:latest

echo "Image pushed successfully!"
