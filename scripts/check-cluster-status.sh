#!/bin/bash

echo "Checking EKS cluster status..."

while true; do
    STATUS=$(aws cloudformation describe-stacks --stack-name eks-unicorn-cluster-stack --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
    
    if [ "$STATUS" = "CREATE_COMPLETE" ]; then
        echo "✅ EKS Cluster is ready!"
        echo "You can now proceed with the deployment steps."
        break
    elif [ "$STATUS" = "CREATE_FAILED" ] || [ "$STATUS" = "ROLLBACK_COMPLETE" ]; then
        echo "❌ EKS Cluster creation failed. Status: $STATUS"
        break
    else
        echo "⏳ EKS Cluster status: $STATUS (waiting...)"
        sleep 30
    fi
done

# Check certificate status
CERT_STATUS=$(aws acm describe-certificate --certificate-arn arn:aws:acm:us-east-1:114805761158:certificate/9827bff9-7ae3-4699-af82-3db304b2c3e8 --query 'Certificate.Status' --output text 2>/dev/null)
echo "📜 Certificate status: $CERT_STATUS"

if [ "$CERT_STATUS" = "PENDING_VALIDATION" ]; then
    echo "⚠️  Please add the DNS validation record for your certificate!"
fi
