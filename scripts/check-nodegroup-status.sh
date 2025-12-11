#!/bin/bash

echo "Checking t3.large node group status..."

while true; do
    STATUS=$(aws eks describe-nodegroup --cluster-name unicorn-cluster --nodegroup-name unicorn-nodegroup-t3large --query 'nodegroup.status' --output text 2>/dev/null)
    
    if [ "$STATUS" = "ACTIVE" ]; then
        echo "✅ t3.large node group is ready!"
        
        # Check nodes
        echo "Checking nodes..."
        kubectl get nodes -o wide
        
        # Check if pods are running on new nodes
        echo "Checking pod distribution..."
        kubectl get pods -o wide
        
        break
    elif [ "$STATUS" = "CREATE_FAILED" ]; then
        echo "❌ Node group creation failed. Status: $STATUS"
        break
    else
        echo "⏳ Node group status: $STATUS (waiting...)"
        sleep 30
    fi
done
