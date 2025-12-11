#!/bin/bash

# AWS Networking Latency Optimization Implementation Script
# This script implements the recommended optimizations for cross-account database access

set -e

# Configuration
REGION="us-east-1"
DB_ACCOUNT_ID="111111111111"
APP_ACCOUNT_ID="222222222222"
VPC_A_ID="vpc-database"
VPC_B_ID="vpc-application"

echo "Starting AWS Networking Latency Optimization..."

# Phase 1: Database Read Replica Creation
create_read_replica() {
    echo "Creating read replica in application AZ..."
    
    aws rds create-db-instance-read-replica \
        --db-instance-identifier "app-db-replica-${REGION}a" \
        --source-db-instance-identifier "primary-database" \
        --availability-zone "${REGION}a" \
        --db-instance-class "db.r5.large" \
        --publicly-accessible false \
        --region $REGION
    
    echo "Read replica creation initiated..."
}

# Phase 2: Enhanced Networking Setup
enable_enhanced_networking() {
    echo "Enabling enhanced networking on EC2 instances..."
    
    # Get all running instances in application VPC
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$VPC_B_ID" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text \
        --region $REGION)
    
    for instance_id in $INSTANCE_IDS; do
        echo "Enabling enhanced networking for $instance_id"
        aws ec2 modify-instance-attribute \
            --instance-id $instance_id \
            --ena-support \
            --region $REGION
    done
}

# Phase 3: Create Placement Group
create_placement_group() {
    echo "Creating cluster placement group..."
    
    aws ec2 create-placement-group \
        --group-name "low-latency-db-cluster" \
        --strategy cluster \
        --region $REGION
    
    echo "Placement group created successfully"
}

# Phase 4: VPC Lattice Service Network Setup
setup_vpc_lattice() {
    echo "Setting up VPC Lattice service network..."
    
    # Create service network
    SERVICE_NETWORK_ARN=$(aws vpc-lattice create-service-network \
        --name "database-service-network" \
        --auth-type "AWS_IAM" \
        --query 'arn' \
        --output text \
        --region $REGION)
    
    echo "Service network created: $SERVICE_NETWORK_ARN"
    
    # Create database service
    SERVICE_ARN=$(aws vpc-lattice create-service \
        --name "database-service" \
        --custom-domain-name "db.internal.company.com" \
        --query 'arn' \
        --output text \
        --region $REGION)
    
    echo "Database service created: $SERVICE_ARN"
    
    # Associate service with service network
    aws vpc-lattice create-service-network-service-association \
        --service-network-identifier $SERVICE_NETWORK_ARN \
        --service-identifier $SERVICE_ARN \
        --region $REGION
    
    echo "Service associated with network"
}

# Phase 5: Cross-Account IAM Policy Setup
setup_cross_account_access() {
    echo "Setting up cross-account access policies..."
    
    # Create policy document
    cat > /tmp/vpc-lattice-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${APP_ACCOUNT_ID}:root"
      },
      "Action": [
        "vpc-lattice:Invoke"
      ],
      "Resource": "arn:aws:vpc-lattice:${REGION}:${DB_ACCOUNT_ID}:service/*"
    }
  ]
}
EOF
    
    echo "Cross-account policy created"
}

# Phase 6: CloudWatch Monitoring Setup
setup_monitoring() {
    echo "Setting up CloudWatch monitoring..."
    
    # Database connection latency alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "High-DB-Connection-Latency" \
        --alarm-description "Database connection latency > 5ms" \
        --metric-name "DatabaseConnections" \
        --namespace "AWS/RDS" \
        --statistic Average \
        --period 300 \
        --threshold 5 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 2 \
        --region $REGION
    
    # VPC Lattice request latency alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "High-VPC-Lattice-Latency" \
        --alarm-description "VPC Lattice request latency > 10ms" \
        --metric-name "RequestLatency" \
        --namespace "AWS/VpcLattice" \
        --statistic Average \
        --period 300 \
        --threshold 10 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 2 \
        --region $REGION
    
    echo "CloudWatch alarms configured"
}

# Main execution
main() {
    echo "=== AWS Networking Latency Optimization ==="
    echo "Region: $REGION"
    echo "Database Account: $DB_ACCOUNT_ID"
    echo "Application Account: $APP_ACCOUNT_ID"
    echo ""
    
    # Execute phases
    create_read_replica
    enable_enhanced_networking
    create_placement_group
    setup_vpc_lattice
    setup_cross_account_access
    setup_monitoring
    
    echo ""
    echo "=== Optimization Complete ==="
    echo "Next steps:"
    echo "1. Update application connection strings to use read replica"
    echo "2. Implement connection pooling in applications"
    echo "3. Configure VPC Lattice target groups"
    echo "4. Test latency improvements"
}

# Run main function
main "$@"
