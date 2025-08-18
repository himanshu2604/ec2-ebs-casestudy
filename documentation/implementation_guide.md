# AWS Multi-Region Web Server Implementation Guide

## Project Overview
Implementation of secure, multi-region web server infrastructure using AWS EC2, EBS, and AMI services with cross-region replication and dynamic storage management capabilities.

**Duration:** 1.3 Hours  
**Services:** EC2 • EBS • AMI • Cross-Region Replication • EBS Snapshots  
**Regions:** US-East-1 (Primary) • US-West-2 (Secondary)

## Prerequisites

### AWS Account Requirements
- Active AWS account with appropriate permissions
- AWS CLI configured with access keys
- SSH key pair for EC2 access

### Required Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

## Phase 1: Primary Infrastructure Setup (US-East-1)

### Step 1: Create Security Group

```bash
# Create security group
aws ec2 create-security-group \
    --group-name XYZ-WebServer-SG \
    --description "Security group for XYZ Corporation web servers" \
    --region us-east-1

# Add inbound rules
aws ec2 authorize-security-group-ingress \
    --group-name XYZ-WebServer-SG \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region us-east-1

aws ec2 authorize-security-group-ingress \
    --group-name XYZ-WebServer-SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region us-east-1

aws ec2 authorize-security-group-ingress \
    --group-name XYZ-WebServer-SG \
    --protocol tcp \
    --port 22 \
    --cidr YOUR_IP_ADDRESS/32 \
    --region us-east-1
```

### Step 2: Launch EC2 Instance

```bash
# Launch EC2 instance
aws ec2 run-instances \
    --image-id ami-0abcdef1234567890 \
    --count 1 \
    --instance-type t3.micro \
    --key-name YOUR_KEY_PAIR \
    --security-groups XYZ-WebServer-SG \
    --user-data file://user-data.sh \
    --region us-east-1 \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=XYZ-Primary-WebServer}]'
```

### Step 3: User Data Script

Create `user-data.sh`:
```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create custom index page
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>XYZ Corporation - Primary Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background-color: #232f3e; color: white; padding: 20px; }
        .content { padding: 20px; }
        .server-info { background-color: #f0f0f0; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>XYZ Corporation Web Server</h1>
        <p>Secure Multi-Region Infrastructure</p>
    </div>
    <div class="content">
        <h2>Server Information</h2>
        <div class="server-info">
            <p><strong>Region:</strong> US-East-1 (Primary)</p>
            <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
            <p><strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
        </div>
        <p>This server is part of a multi-region, highly available infrastructure.</p>
    </div>
</body>
</html>
EOF

# Install additional packages
yum install -y htop tree wget curl
```

## Phase 2: Custom AMI Creation

### Step 1: Prepare Instance for AMI Creation

```bash
# Connect to your instance
ssh -i YOUR_KEY.pem ec2-user@YOUR_INSTANCE_IP

# Clean up instance for AMI creation
sudo yum clean all
sudo rm -rf /tmp/*
sudo rm -rf /var/log/*
sudo history -c
```

### Step 2: Create Custom AMI

```bash
# Create AMI from instance
aws ec2 create-image \
    --instance-id i-1234567890abcdef0 \
    --name "XYZ-Corp-WebServer-v1.0" \
    --description "Custom web server AMI for XYZ Corporation" \
    --region us-east-1 \
    --tag-specifications 'ResourceType=image,Tags=[{Key=Name,Value=XYZ-Corp-WebServer-v1.0},{Key=Environment,Value=Production}]'
```

## Phase 3: Cross-Region Replication

### Step 1: Copy AMI to Secondary Region

```bash
# Copy AMI to US-West-2
aws ec2 copy-image \
    --source-region us-east-1 \
    --source-image-id ami-12345678 \
    --name "XYZ-Corp-WebServer-v1.0-West" \
    --description "XYZ Corporation web server AMI - West Region" \
    --region us-west-2
```

### Step 2: Create Security Group in US-West-2

```bash
# Create security group in us-west-2
aws ec2 create-security-group \
    --group-name XYZ-WebServer-SG-West \
    --description "Security group for XYZ Corporation web servers - West" \
    --region us-west-2

# Add same inbound rules as primary region
aws ec2 authorize-security-group-ingress \
    --group-name XYZ-WebServer-SG-West \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region us-west-2

aws ec2 authorize-security-group-ingress \
    --group-name XYZ-WebServer-SG-West \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region us-west-2

aws ec2 authorize-security-group-ingress \
    --group-name XYZ-WebServer-SG-West \
    --protocol tcp \
    --port 22 \
    --cidr YOUR_IP_ADDRESS/32 \
    --region us-west-2
```

### Step 3: Launch Instance in Secondary Region

```bash
# Launch instance using copied AMI
aws ec2 run-instances \
    --image-id ami-copied-id \
    --count 1 \
    --instance-type t3.micro \
    --key-name YOUR_KEY_PAIR_WEST \
    --security-groups XYZ-WebServer-SG-West \
    --region us-west-2 \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=XYZ-Secondary-WebServer}]'
```

## Phase 4: EBS Volume Management

### Step 1: Create and Attach EBS Volumes

```bash
# Create first EBS volume
aws ec2 create-volume \
    --size 8 \
    --volume-type gp3 \
    --availability-zone us-east-1a \
    --region us-east-1 \
    --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=XYZ-Data-Volume-1}]'

# Create second EBS volume
aws ec2 create-volume \
    --size 8 \
    --volume-type gp3 \
    --availability-zone us-east-1a \
    --region us-east-1 \
    --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=XYZ-Data-Volume-2}]'

# Attach volumes to instance
aws ec2 attach-volume \
    --volume-id vol-12345678 \
    --instance-id i-1234567890abcdef0 \
    --device /dev/sdf \
    --region us-east-1

aws ec2 attach-volume \
    --volume-id vol-87654321 \
    --instance-id i-1234567890abcdef0 \
    --device /dev/sdg \
    --region us-east-1
```

### Step 2: Format and Mount Volumes

```bash
# Connect to instance and format volumes
ssh -i YOUR_KEY.pem ec2-user@YOUR_INSTANCE_IP

# Format the volumes
sudo mkfs -t ext4 /dev/xvdf
sudo mkfs -t ext4 /dev/xvdg

# Create mount points
sudo mkdir /data1
sudo mkdir /data2

# Mount the volumes
sudo mount /dev/xvdf /data1
sudo mount /dev/xvdg /data2

# Add to fstab for persistent mounting
echo '/dev/xvdf /data1 ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
echo '/dev/xvdg /data2 ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# Verify mounts
df -h
```

### Step 3: Create Test Data

```bash
# Create test files
sudo touch /data1/test-file-1.txt
sudo touch /data2/test-file-2.txt
echo "Test data in volume 1" | sudo tee /data1/test-file-1.txt
echo "Test data in volume 2" | sudo tee /data2/test-file-2.txt
```

## Phase 5: Volume Management Operations

### Step 1: Volume Detachment and Deletion

```bash
# Unmount volume 2
sudo umount /data2

# Remove from fstab
sudo sed -i '/\/data2/d' /etc/fstab

# Detach volume from instance
aws ec2 detach-volume \
    --volume-id vol-87654321 \
    --region us-east-1

# Delete volume (after detachment is complete)
aws ec2 delete-volume \
    --volume-id vol-87654321 \
    --region us-east-1
```

### Step 2: Volume Extension

```bash
# Create snapshot before modification
aws ec2 create-snapshot \
    --volume-id vol-12345678 \
    --description "Backup before volume extension" \
    --region us-east-1

# Unmount the volume
sudo umount /data1

# Detach volume
aws ec2 detach-volume \
    --volume-id vol-12345678 \
    --region us-east-1

# Modify volume size
aws ec2 modify-volume \
    --volume-id vol-12345678 \
    --size 16 \
    --region us-east-1

# Reattach volume
aws ec2 attach-volume \
    --volume-id vol-12345678 \
    --instance-id i-1234567890abcdef0 \
    --device /dev/sdf \
    --region us-east-1

# Resize file system
sudo mount /dev/xvdf /data1
sudo resize2fs /dev/xvdf

# Verify new size
df -h /data1
```

## Phase 6: Backup Strategy Implementation

### Step 1: Create EBS Snapshots

```bash
# Create snapshot of all volumes
aws ec2 create-snapshot \
    --volume-id vol-12345678 \
    --description "Daily backup of data volume 1 - $(date +%Y-%m-%d)" \
    --region us-east-1 \
    --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Name,Value=XYZ-Data-Backup},{Key=Schedule,Value=Daily}]'
```

### Step 2: Automated Backup Script

Create `backup-script.sh`:
```bash
#!/bin/bash
# Automated EBS snapshot script

VOLUME_ID="vol-12345678"
REGION="us-east-1"
DESCRIPTION="Automated backup - $(date '+%Y-%m-%d %H:%M:%S')"

# Create snapshot
SNAPSHOT_ID=$(aws ec2 create-snapshot \
    --volume-id $VOLUME_ID \
    --description "$DESCRIPTION" \
    --region $REGION \
    --output text \
    --query 'SnapshotId')

echo "Created snapshot: $SNAPSHOT_ID"

# Delete snapshots older than 7 days
aws ec2 describe-snapshots \
    --owner-ids self \
    --filters "Name=volume-id,Values=$VOLUME_ID" \
    --region $REGION \
    --query 'Snapshots[?StartTime<=`2024-01-01`].SnapshotId' \
    --output text | xargs -r aws ec2 delete-snapshot --region $REGION --snapshot-id
```

## Validation and Testing

### Step 1: Web Server Functionality Test

```bash
# Test primary region
curl -I http://PRIMARY_INSTANCE_IP
curl http://PRIMARY_INSTANCE_IP

# Test secondary region
curl -I http://SECONDARY_INSTANCE_IP
curl http://SECONDARY_INSTANCE_IP
```

### Step 2: Performance Testing

```bash
# Install Apache Bench for load testing
sudo yum install -y httpd-tools

# Test primary server
ab -n 1000 -c 10 http://PRIMARY_INSTANCE_IP/

# Test secondary server
ab -n 1000 -c 10 http://SECONDARY_INSTANCE_IP/
```

### Step 3: Disaster Recovery Test

```bash
# Simulate primary region failure by stopping instance
aws ec2 stop-instances \
    --instance-ids i-1234567890abcdef0 \
    --region us-east-1

# Verify secondary region continues to serve traffic
curl http://SECONDARY_INSTANCE_IP
```

## Monitoring and Maintenance

### CloudWatch Monitoring Setup

```bash
# Enable detailed monitoring
aws ec2 monitor-instances \
    --instance-ids i-1234567890abcdef0 \
    --region us-east-1

aws ec2 monitor-instances \
    --instance-ids i-0987654321fedcba0 \
    --region us-west-2
```

### Cost Optimization Commands

```bash
# List unused volumes
aws ec2 describe-volumes \
    --filters "Name=status,Values=available" \
    --region us-east-1

# List old snapshots
aws ec2 describe-snapshots \
    --owner-ids self \
    --region us-east-1 \
    --query 'Snapshots[?StartTime<=`2024-01-01`]'
```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Instance Launch Failures**
   ```bash
   # Check instance status
   aws ec2 describe-instance-status --instance-ids i-1234567890abcdef0
   ```

2. **Volume Attachment Issues**
   ```bash
   # Check volume status
   aws ec2 describe-volumes --volume-ids vol-12345678
   ```

3. **AMI Copy Failures**
   ```bash
   # Check image status
   aws ec2 describe-images --image-ids ami-12345678 --region us-west-2
   ```

## Security Best Practices

- Use IAM roles instead of access keys when possible
- Regularly rotate SSH keys
- Enable CloudTrail for audit logging
- Use VPC instead of EC2-Classic
- Encrypt EBS volumes at rest
- Implement regular security updates

## Cost Analysis

### Monthly Cost Breakdown
- EC2 (US-East-1): $8.50
- EC2 (US-West-2): $8.50
- EBS Volume (16 GB): $1.60
- EBS Snapshots (~20 GB): $1.00
- Data Transfer: $2.00
- **Total: $21.60/month**

### Cost Optimization Tips
1. Use Reserved Instances for long-term deployments (30% savings)
2. Implement snapshot lifecycle policies
3. Right-size instances based on actual usage
4. Use gp3 volumes instead of gp2 for better cost/performance
5. Delete unused resources regularly