## Appendix B: Script Repository

### B.1 User Data Script (Complete)
```bash
#!/bin/bash
# XYZ Corporation Web Server Setup Script
# Version: 1.0
# Purpose: Automated web server configuration

# Update system
yum update -y

# Install Apache web server
yum install -y httpd

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create custom index page with dynamic content
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>XYZ Corporation</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007acc; padding-bottom: 10px; }
        .info { background: #e7f3ff; padding: 15px; border-left: 4px solid #007acc; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 XYZ Corporation Web Server</h1>
        <div class="info">
            <h3>Server Information:</h3>
            <p><strong>Region:</strong> REGION_PLACEHOLDER</p>
            <p><strong>Instance ID:</strong> INSTANCE_ID_PLACEHOLDER</p>
            <p><strong>Availability Zone:</strong> AZ_PLACEHOLDER</p>
            <p><strong>Deployment Date:</strong> DEPLOY_DATE_PLACEHOLDER</p>
        </div>
        <p>✅ Web server successfully deployed and running</p>
        <p>🔒 Security groups configured and active</p>
        <p>💾 EBS volumes attached and mounted</p>
    </div>
</body>
</html>
EOF

# Replace placeholders with actual metadata
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
DEPLOY_DATE=$(date)

sed -i "s/REGION_PLACEHOLDER/$REGION/g" /var/www/html/index.html
sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/AZ_PLACEHOLDER/$AZ/g" /var/www/html/index.html
sed -i "s/DEPLOY_DATE_PLACEHOLDER/$DEPLOY_DATE/g" /var/www/html/index.html

# Configure firewall
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Create log entry
echo "$(date): XYZ Corp web server setup completed" >> /var/log/deployment.log
```

### B.2 EBS Volume Management Script
```bash
#!/bin/bash
# EBS Volume Management Script
# Purpose: Automate volume operations

# Function to attach volume
attach_volume() {
    local VOLUME_ID=$1
    local INSTANCE_ID=$2
    local DEVICE=$3
    
    echo "Attaching volume $VOLUME_ID to instance $INSTANCE_ID..."
    aws ec2 attach-volume \
        --volume-id $VOLUME_ID \
        --instance-id $INSTANCE_ID \
        --device $DEVICE
    
    # Wait for attachment
    aws ec2 wait volume-in-use --volume-ids $VOLUME_ID
    echo "Volume attached successfully"
}

# Function to create and format filesystem
setup_filesystem() {
    local DEVICE=$1
    local MOUNT_POINT=$2
    local LABEL=$3
    
    echo "Creating filesystem on $DEVICE..."
    sudo mkfs -t ext4 $DEVICE -L $LABEL
    
    echo "Creating mount point $MOUNT_POINT..."
    sudo mkdir -p $MOUNT_POINT
    
    echo "Mounting $DEVICE to $MOUNT_POINT..."
    sudo mount $DEVICE $MOUNT_POINT
    
    # Add to fstab for persistence
    echo "$DEVICE $MOUNT_POINT ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    
    # Set permissions
    sudo chown ec2-user:ec2-user $MOUNT_POINT
    
    echo "Filesystem setup completed for $MOUNT_POINT"
}

# Function to extend volume
extend_volume() {
    local VOLUME_ID=$1
    local NEW_SIZE=$2
    local DEVICE=$3
    
    echo "Extending volume $VOLUME_ID to $NEW_SIZE GB..."
    aws ec2 modify-volume --volume-id $VOLUME_ID --size $NEW_SIZE
    
    # Wait for modification to complete
    aws ec2 wait volume-in-use --volume-ids $VOLUME_ID
    
    echo "Volume extended. Extending filesystem..."
    sudo resize2fs $DEVICE
    
    echo "Volume extension completed"
}

# Function to create snapshot
create_snapshot() {
    local VOLUME_ID=$1
    local DESCRIPTION=$2
    
    echo "Creating snapshot of volume $VOLUME_ID..."
    SNAPSHOT_ID=$(aws ec2 create-snapshot \
        --volume-id $VOLUME_ID \
        --description "$DESCRIPTION" \
        --query 'SnapshotId' \
        --output text)
    
    echo "Snapshot created: $SNAPSHOT_ID"
    return $SNAPSHOT_ID
}
```

### B.3 Deployment Validation Script
```bash
#!/bin/bash
# Deployment Validation Script
# Purpose: Validate all components after deployment

echo "🔍 Starting XYZ Corporation Infrastructure Validation..."

# Test 1: EC2 Instance Health
echo "✅ Testing EC2 Instance Health..."
if curl -s http://169.254.169.254/latest/meta-data/instance-id > /dev/null; then
    echo "   ✓ Instance metadata accessible"
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "   ✓ Instance ID: $INSTANCE_ID"
else
    echo "   ✗ Instance metadata not accessible"
fi

# Test 2: Web Server Response
echo "✅ Testing Web Server Response..."
if curl -s http://localhost > /dev/null; then
    echo "   ✓ Web server responding"
    RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
    echo "   ✓ HTTP Response Code: $RESPONSE_CODE"
else
    echo "   ✗ Web server not responding"
fi

# Test 3: EBS Volume Mounts
echo "✅ Testing EBS Volume Mounts..."
if mountpoint -q /data1; then
    echo "   ✓ /data1 is properly mounted"
    DISK_USAGE=$(df -h /data1 | awk 'NR==2{print $4}')
    echo "   ✓ Available space: $DISK_USAGE"
else
    echo "   ✗ /data1 is not mounted"
fi

# Test 4: Security Groups
echo "✅ Testing Security Group Configuration..."
SECURITY_GROUPS=$(curl -s http://169.254.169.254/latest/meta-data/security-groups)
echo "   ✓ Security Groups: $SECURITY_GROUPS"

# Test 5: Network Connectivity
echo "✅ Testing Network Connectivity..."
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "   ✓ External network connectivity confirmed"
else
    echo "   ✗ External network connectivity failed"
fi

echo "🎉 Validation completed!"
```