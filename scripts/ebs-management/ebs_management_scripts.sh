# scripts/ebs-management/create-and-attach-volume.sh
#!/bin/bash
# EBS Volume Creation and Attachment Script
# Usage: ./create-and-attach-volume.sh [size] [instance-id] [mount-point]

set -e

# Default values
DEFAULT_SIZE=8
DEFAULT_VOLUME_TYPE="gp3"
LOG_FILE="/var/log/ebs-operations.log"

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

usage() {
    echo "Usage: $0 <size> <instance-id> <mount-point> [region]"
    echo "Example: $0 10 i-1234567890abcdef0 /data1 us-east-1"
    exit 1
}

# Check parameters
if [ $# -lt 3 ]; then
    usage
fi

SIZE=$1
INSTANCE_ID=$2
MOUNT_POINT=$3
REGION=${4:-us-east-1}

# Get instance availability zone
AZ=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' \
    --output text)

if [ "$AZ" = "None" ]; then
    log "ERROR: Could not determine availability zone for instance $INSTANCE_ID"
    exit 1
fi

log "Creating EBS volume..."
log "Size: ${SIZE}GB, Type: $DEFAULT_VOLUME_TYPE, AZ: $AZ"

# Create EBS volume
VOLUME_ID=$(aws ec2 create-volume \
    --size $SIZE \
    --volume-type $DEFAULT_VOLUME_TYPE \
    --availability-zone $AZ \
    --region $REGION \
    --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=XYZ-Data-Volume-$(date +%Y%m%d-%H%M%S)},{Key=MountPoint,Value=$MOUNT_POINT}]" \
    --query 'VolumeId' \
    --output text)

log "Created volume: $VOLUME_ID"

# Wait for volume to be available
log "Waiting for volume to be available..."
aws ec2 wait volume-available --volume-ids $VOLUME_ID --region $REGION

# Find available device
DEVICES=(/dev/sdf /dev/sdg /dev/sdh /dev/sdi /dev/sdj)
DEVICE=""

for dev in "${DEVICES[@]}"; do
    if ! aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --region $REGION \
        --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='$dev']" \
        --output text | grep -q .; then
        DEVICE=$dev
        break
    fi
done

if [ -z "$DEVICE" ]; then
    log "ERROR: No available device found"
    exit 1
fi

log "Using device: $DEVICE"

# Attach volume
log "Attaching volume to instance..."
aws ec2 attach-volume \
    --volume-id $VOLUME_ID \
    --instance-id $INSTANCE_ID \
    --device $DEVICE \
    --region $REGION

# Wait for attachment
log "Waiting for volume attachment..."
aws ec2 wait volume-in-use --volume-ids $VOLUME_ID --region $REGION

# Create mount script for the instance
cat > /tmp/mount-volume.sh << EOF
#!/bin/bash
# Auto-generated mount script for volume $VOLUME_ID

DEVICE_PATH=\$(lsblk -no KNAME,TYPE | grep disk | tail -1 | awk '{print "/dev/" \$1}')
if [ -z "\$DEVICE_PATH" ]; then
    DEVICE_PATH="/dev/xvd\$(echo $DEVICE | sed 's/.*sd//')"
fi

echo "Using device path: \$DEVICE_PATH"

# Check if volume is already formatted
if ! blkid \$DEVICE_PATH > /dev/null 2>&1; then
    echo "Formatting volume..."
    mkfs -t ext4 \$DEVICE_PATH
else
    echo "Volume is already formatted"
fi

# Create mount point
mkdir -p $MOUNT_POINT

# Mount volume
mount \$DEVICE_PATH $MOUNT_POINT

# Add to fstab
if ! grep -q "$MOUNT_POINT" /etc/fstab; then
    echo "\$DEVICE_PATH $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# Set permissions
chown ec2-user:ec2-user $MOUNT_POINT
chmod 755 $MOUNT_POINT

echo "Volume mounted successfully at $MOUNT_POINT"
df -h $MOUNT_POINT
EOF

log "Volume attachment completed"
log "Volume ID: $VOLUME_ID"
log "Device: $DEVICE"
log "Instance: $INSTANCE_ID"
log "Mount Point: $MOUNT_POINT"

echo "To complete the setup, run the following on the instance:"
echo "scp /tmp/mount-volume.sh ec2-user@INSTANCE_IP:/tmp/"
echo "ssh ec2-user@INSTANCE_IP 'sudo bash /tmp/mount-volume.sh'"

log "EBS volume creation and attachment completed successfully"

# ================================================================
# scripts/ebs-management/detach-and-delete-volume.sh
#!/bin/bash
# EBS Volume Detachment and Deletion Script
# Usage: ./detach-and-delete-volume.sh [volume-id] [mount-point]

set -e

LOG_FILE="/var/log/ebs-operations.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

usage() {
    echo "Usage: $0 <volume-id> <mount-point> [region]"
    echo "Example: $0 vol-1234567890abcdef0 /data1 us-east-1"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

VOLUME_ID=$1
MOUNT_POINT=$2
REGION=${3:-us-east-1}

log "Starting volume detachment process..."
log "Volume ID: $VOLUME_ID"
log "Mount Point: $MOUNT_POINT"

# Get volume information
INSTANCE_ID=$(aws ec2 describe-volumes \
    --volume-ids $VOLUME_ID \
    --region $REGION \
    --query 'Volumes[0].Attachments[0].InstanceId' \
    --output text)

if [ "$INSTANCE_ID" = "None" ] || [ "$INSTANCE_ID" = "null" ]; then
    log "Volume is not attached to any instance"
    INSTANCE_ID=""
else
    log "Volume is attached to instance: $INSTANCE_ID"
fi

# Create unmount script if instance is specified
if [ -n "$INSTANCE_ID" ]; then
    cat > /tmp/unmount-volume.sh << EOF
#!/bin/bash
# Auto-generated unmount script for volume $VOLUME_ID

if mountpoint -q $MOUNT_POINT; then
    echo "Unmounting $MOUNT_POINT..."
    umount $MOUNT_POINT
    echo "Volume unmounted successfully"
else
    echo "Volume is not mounted at $MOUNT_POINT"
fi

# Remove from fstab
sed -i "\\|$MOUNT_POINT|d" /etc/fstab

echo "Unmount process completed"
EOF

    echo "To safely unmount the volume, run the following on the instance:"
    echo "scp /tmp/unmount-volume.sh ec2-user@INSTANCE_IP:/tmp/"
    echo "ssh ec2-user@INSTANCE_IP 'sudo bash /tmp/unmount-volume.sh'"
    echo ""
    read -p "Have you unmounted the volume? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Aborting - please unmount the volume first"
        exit 1
    fi
fi

# Detach volume
if [ -n "$INSTANCE_ID" ]; then
    log "Detaching volume from instance..."
    aws ec2 detach-volume \
        --volume-id $VOLUME_ID \
        --region $REGION

    log "Waiting for volume to detach..."
    aws ec2 wait volume-available --volume-ids $VOLUME_ID --region $REGION
    log "Volume detached successfully"
fi

# Ask for confirmation before deletion
echo "WARNING: This will permanently delete the volume and all its data!"
read -p "Are you sure you want to delete volume $VOLUME_ID? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Aborting volume deletion"
    exit 1
fi

# Delete volume
log "Deleting volume..."
aws ec2 delete-volume \
    --volume-id $VOLUME_ID \
    --region $REGION

log "Volume deletion initiated"
log "Volume $VOLUME_ID has been deleted successfully"

# ================================================================
# scripts/ebs-management/extend-volume.sh
#!/bin/bash
# EBS Volume Extension Script
# Usage: ./extend-volume.sh [volume-id] [new-size] [mount-point]

set -e

LOG_FILE="/var/log/ebs-operations.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

usage() {
    echo "Usage: $0 <volume-id> <new-size> <mount-point> [region]"
    echo "Example: $0 vol-1234567890abcdef0 16 /data1 us-east-1"
    exit 1
}

if [ $# -lt 3 ]; then
    usage
fi

VOLUME_ID=$1
NEW_SIZE=$2
MOUNT_POINT=$3
REGION=${4:-us-east-1}

log "Starting volume extension process..."
log "Volume ID: $VOLUME_ID"
log "New Size: ${NEW_SIZE}GB"
log "Mount Point: $MOUNT_POINT"

# Get current volume information
CURRENT_SIZE=$(aws ec2 describe-volumes \
    --volume-ids $VOLUME_ID \
    --region $REGION \
    --query 'Volumes[0].Size' \
    --output text)

INSTANCE_ID=$(aws ec2 describe-volumes \
    --volume-ids $VOLUME_ID \
    --region $REGION \
    --query 'Volumes[0].Attachments[0].InstanceId' \
    --output text)

DEVICE=$(aws ec2 describe-volumes \
    --volume-ids $VOLUME_ID \
    --region $REGION \
    --query 'Volumes[0].Attachments[0].Device' \
    --output text)

log "Current size: ${CURRENT_SIZE}GB"
log "Attached to instance: $INSTANCE_ID"
log "Device: $DEVICE"

# Validate new size
if [ "$NEW_SIZE" -le "$CURRENT_SIZE" ]; then
    log "ERROR: New size must be larger than current size ($CURRENT_SIZE GB)"
    exit 1
fi

# Create backup snapshot first
log "Creating backup snapshot before extension..."
SNAPSHOT_ID=$(aws ec2 create-snapshot \
    --volume-id $VOLUME_ID \
    --description "Backup before extending volume to ${NEW_SIZE}GB - $(date)" \
    --region $REGION \
    --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=Pre-Extension-Backup-$(date +%Y%m%d-%H%M%S)},{Key=VolumeId,Value=$VOLUME_ID}]" \
    --query 'SnapshotId' \
    --output text)

log "Created backup snapshot: $SNAPSHOT_ID"
log "Waiting for snapshot to complete..."
aws ec2 wait snapshot-completed --snapshot-ids $SNAPSHOT_ID --region $REGION
log "Snapshot completed successfully"

# Modify volume size
log "Extending volume to ${NEW_SIZE}GB..."
aws ec2 modify-volume \
    --volume-id $VOLUME_ID \
    --size $NEW_SIZE \
    --region $REGION

log "Waiting for volume modification to complete..."
aws ec2 wait volume-in-use --volume-ids $VOLUME_ID --region $REGION

# Create script to extend filesystem
cat > /tmp/extend-filesystem.sh << EOF
#!/bin/bash
# Auto-generated filesystem extension script

DEVICE_PATH="/dev/xvd\$(echo $DEVICE | sed 's/.*sd//')"

echo "Extending filesystem on \$DEVICE_PATH..."

# For ext4 filesystem (most common)
if blkid \$DEVICE_PATH | grep -q ext4; then
    echo "Detected ext4 filesystem"
    resize2fs \$DEVICE_PATH
elif blkid \$DEVICE_PATH | grep -q xfs; then
    echo "Detected xfs filesystem"
    xfs_growfs $MOUNT_POINT
else
    echo "Unsupported filesystem type"
    exit 1
fi

echo "Filesystem extension completed"
echo "New filesystem size:"
df -h $MOUNT_POINT
EOF

log "Volume extension completed"
log "Backup snapshot: $SNAPSHOT_ID"

echo "To complete the filesystem extension, run the following on the instance:"
echo "scp /tmp/extend-filesystem.sh ec2-user@INSTANCE_IP:/tmp/"
echo "ssh ec2-user@INSTANCE_IP 'sudo bash /tmp/extend-filesystem.sh'"

log "EBS volume extension process completed successfully"

# ================================================================
# scripts/ebs-management/list-volumes.sh
#!/bin/bash
# List EBS Volumes Script
# Usage: ./list-volumes.sh [region]

REGION=${1:-us-east-1}

echo "EBS Volumes in region: $REGION"
echo "======================================="

aws ec2 describe-volumes \
    --region $REGION \
    --query 'Volumes[*].[VolumeId,Size,VolumeType,State,Attachments[0].InstanceId,Tags[?Key==`Name`].Value|[0]]' \
    --output table \
    --filters "Name=tag:Name,Values=XYZ-*"

echo ""
echo "Volume Details:"
echo "==============="

for volume_id in $(aws ec2 describe-volumes \
    --region $REGION \
    --query 'Volumes[*].VolumeId' \
    --output text \
    --filters "Name=tag:Name,Values=XYZ-*"); do
    
    echo "Volume ID: $volume_id"
    
    volume_info=$(aws ec2 describe-volumes \
        --volume-ids $volume_id \
        --region $REGION \
        --query 'Volumes[0].[Size,VolumeType,State,AvailabilityZone,CreateTime,Attachments[0].InstanceId,Attachments[0].Device,Attachments[0].State]' \
        --output text)
    
    echo "  Size: $(echo $volume_info | awk '{print $1}') GB"
    echo "  Type: $(echo $volume_info | awk '{print $2}')"
    echo "  State: $(echo $volume_info | awk '{print $3}')"
    echo "  AZ: $(echo $volume_info | awk '{print $4}')"
    echo "  Created: $(echo $volume_info | awk '{print $5}')"
    
    instance_id=$(echo $volume_info | awk '{print $6}')
    if [ "$instance_id" != "None" ] && [ -n "$instance_id" ]; then
        echo "  Attached to: $instance_id"
        echo "  Device: $(echo $volume_info | awk '{print $7}')"
        echo "  Attachment State: $(echo $volume_info | awk '{print $8}')"
    else
        echo "  Status: Unattached"
    fi
    
    echo ""
done