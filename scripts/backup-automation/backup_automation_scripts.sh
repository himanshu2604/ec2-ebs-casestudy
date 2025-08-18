# scripts/backup-automation/create-snapshots.sh
#!/bin/bash
# EBS Snapshot Creation Script
# Usage: ./create-snapshots.sh [volume-id] [description] [region]

set -e

LOG_FILE="/var/log/backup-operations.log"
DEFAULT_RETENTION_DAYS=7

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

usage() {
    echo "Usage: $0 <volume-id> [description] [region]"
    echo "       $0 --all [region]  # Backup all XYZ volumes"
    echo "Example: $0 vol-1234567890abcdef0 'Daily backup' us-east-1"
    echo "         $0 --all us-east-1"
    exit 1
}

create_snapshot() {
    local volume_id=$1
    local description=$2
    local region=$3
    
    log "Creating snapshot for volume: $volume_id"
    
    # Get volume name tag
    volume_name=$(aws ec2 describe-volumes \
        --volume-ids $volume_id \
        --region $region \
        --query 'Volumes[0].Tags[?Key==`Name`].Value|[0]' \
        --output text)
    
    if [ "$volume_name" = "None" ] || [ -z "$volume_name" ]; then
        volume_name="Unnamed-Volume"
    fi
    
    # Create snapshot
    snapshot_id=$(aws ec2 create-snapshot \
        --volume-id $volume_id \
        --description "$description" \
        --region $region \
        --tag-specifications "ResourceType=snapshot,Tags=[
            {Key=Name,Value=Backup-$volume_name-$(date +%Y%m%d-%H%M%S)},
            {Key=VolumeId,Value=$volume_id},
            {Key=CreatedBy,Value=automated-backup},
            {Key=RetentionDays,Value=$DEFAULT_RETENTION_DAYS}
        ]" \
        --query 'SnapshotId' \
        --output text)
    
    log "Created snapshot: $snapshot_id for volume: $volume_id"
    echo "Snapshot ID: $snapshot_id"
    
    return 0
}

# Main logic
if [ $# -lt 1 ]; then
    usage
fi

if [ "$1" = "--all" ]; then
    REGION=${2:-us-east-1}
    DESCRIPTION="Automated daily backup - $(date '+%Y-%m-%d %H:%M:%S')"
    
    log "Starting backup of all XYZ volumes in region: $REGION"
    
    # Get all XYZ volumes
    volume_ids=$(aws ec2 describe-volumes \
        --region $REGION \
        --filters "Name=tag:Name,Values=XYZ-*" \
        --query 'Volumes[*].VolumeId' \
        --output text)
    
    if [ -z "$volume_ids" ]; then
        log "No XYZ volumes found in region $REGION"
        exit 1
    fi
    
    snapshot_count=0
    for volume_id in $volume_ids; do
        if create_snapshot "$volume_id" "$DESCRIPTION" "$REGION"; then
            ((snapshot_count++))
        fi
    done
    
    log "Created $snapshot_count snapshots successfully"
    
else
    VOLUME_ID=$1
    DESCRIPTION=${2:-"Manual backup - $(date '+%Y-%m-%d %H:%M:%S')"}
    REGION=${3:-us-east-1}
    
    create_snapshot "$VOLUME_ID" "$DESCRIPTION" "$REGION"
fi

log "Snapshot creation process completed"

# ================================================================
# scripts/backup-automation/cleanup-old-snapshots.sh
#!/bin/bash
# Cleanup Old Snapshots Script
# Usage: ./cleanup-old-snapshots.sh [retention-days] [region]

set -e

LOG_FILE="/var/log/backup-operations.log"
DEFAULT_RETENTION_DAYS=7

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

usage() {
    echo "Usage: $0 [retention-days] [region]"
    echo "Example: $0 7 us-east-1"
    echo "Default retention: $DEFAULT_RETENTION_DAYS days"
    exit 1
}

RETENTION_DAYS=${1:-$DEFAULT_RETENTION_DAYS}
REGION=${2:-us-east-1}

log "Starting cleanup of snapshots older than $RETENTION_DAYS days in region $REGION"

# Calculate cutoff date
CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" '+%Y-%m-%d')

log "Cutoff date: $CUTOFF_DATE"

# Find old snapshots created by our backup system
old_snapshots=$(aws ec2 describe-snapshots \
    --owner-ids self \
    --region $REGION \
    --filters "Name=tag:CreatedBy,Values=automated-backup" \
    --query "Snapshots[?StartTime<='$CUTOFF_DATE'].SnapshotId" \
    --output text)

if [ -z "$old_snapshots" ]; then
    log "No old snapshots found to delete"
    exit 0
fi

deleted_count=0
for snapshot_id in $old_snapshots; do
    log "Deleting snapshot: $snapshot_id"
    
    # Get snapshot info before deletion
    snapshot_info=$(aws ec2 describe-snapshots \
        --snapshot-ids $snapshot_id \
        --region $REGION \
        --query 'Snapshots[0].[StartTime,Description,VolumeSize]' \
        --output text)
    
    log "Snapshot details: $snapshot_info"
    
    # Delete snapshot
    if aws ec2 delete-snapshot --snapshot-id $snapshot_id --region $REGION; then
        log "Successfully deleted snapshot: $snapshot_id"
        ((deleted_count++))
    else
        log "Failed to delete snapshot: $snapshot_id"
    fi
done

log "Cleanup completed. Deleted $deleted_count snapshots"

# ================================================================
# scripts/backup-automation/restore-from-snapshot.sh
#!/bin/bash
# Restore EBS Volume from Snapshot Script
# Usage: ./restore-from-snapshot.sh [snapshot-id] [availability-zone] [region]

set -e

LOG_FILE="/var/log/backup-operations.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

usage() {
    echo "Usage: $0 <snapshot-id> <availability-zone> [region]"
    echo "Example: $0 snap-1234567890abcdef0 us-east-1a us-east-1"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

SNAPSHOT_ID=$1
AVAILABILITY_ZONE=$2
REGION=${3:-us-east-1}

log "Starting volume restoration from snapshot: $SNAPSHOT_ID"

# Verify snapshot exists
if ! aws ec2 describe-snapshots \
    --snapshot-ids $SNAPSHOT_ID \
    --region $REGION > /dev/null 2>&1; then
    log "ERROR: Snapshot $SNAPSHOT_ID not found"
    exit 1
fi

# Get snapshot information
snapshot_info=$(aws ec2 describe-snapshots \
    --snapshot-ids $SNAPSHOT_ID \
    --region $REGION \
    --query 'Snapshots[0].[VolumeSize,Description,StartTime,State]' \
    --output text)

volume_size=$(echo $snapshot_info | awk '{print $1}')
description=$(echo $snapshot_info | awk '{print $2}')
start_time=$(echo $snapshot_info | awk '{print $3}')
state=$(echo $snapshot_info | awk '{print $4}')

log "Snapshot information:"
log "  Size: ${volume_size}GB"
log "  Description: $description"
log "  Created: $start_time"
log "  State: $state"

if [ "$state" != "completed" ]; then
    log "ERROR: Snapshot is not in completed state: $state"
    exit 1
fi

# Create volume from snapshot
log "Creating volume from snapshot in AZ: $AVAILABILITY_ZONE"

volume_id=$(aws ec2 create-volume \
    --snapshot-id $SNAPSHOT_ID \
    --availability-zone $AVAILABILITY_ZONE \
    --volume-type gp3 \
    --region $REGION \
    --tag-specifications "ResourceType=volume,Tags=[
        {Key=Name,Value=Restored-from-$SNAPSHOT_ID-$(date +%Y%m%d-%H%M%S)},
        {Key=SourceSnapshot,Value=$SNAPSHOT_ID},
        {Key=RestoredBy,Value=automated-restore},
        {Key=RestoreDate,Value=$(date '+%Y-%m-%d %H:%M:%S')}
    ]" \
    --query 'VolumeId' \
    --output text)

log "Created volume: $volume_id"

# Wait for volume to be available
log "Waiting for volume to be available..."
aws ec2 wait volume-available --volume-ids $volume_id --region $REGION

log "Volume restoration completed successfully"
log "New Volume ID: $volume_id"
log "Original Snapshot: $SNAPSHOT_ID"

echo "Volume restored successfully!"
echo "Volume ID: $volume_id"
echo "Size: ${volume_size}GB"
echo "Availability Zone: $AVAILABILITY_ZONE"
echo ""
echo "To attach this volume to an instance:"
echo "aws ec2 attach-volume --volume-id $volume_id --instance-id INSTANCE_ID --device /dev/sdf --region $REGION"

# ================================================================
# scripts/backup-automation/cross-region-backup.sh
#!/bin/bash
# Cross-Region Backup Script
# Usage: ./cross-region-backup.sh [source-region] [target-region]

set -e

LOG_FILE="/var/log/backup-operations.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

usage() {
    echo "Usage: $0 [source-region] [target-region]"
    echo "Example: $0 us-east-1 us-west-2"
    echo "Default: us-east-1 to us-west-2"
    exit 1
}

SOURCE_REGION=${1:-us-east-1}
TARGET_REGION=${2:-us-west-2}

log "Starting cross-region backup from $SOURCE_REGION to $TARGET_REGION"

# Get all snapshots created today in source region
today=$(date '+%Y-%m-%d')
recent_snapshots=$(aws ec2 describe-snapshots \
    --owner-ids self \
    --region $SOURCE_REGION \
    --filters "Name=tag:CreatedBy,Values=automated-backup" \
    --query "Snapshots[?StartTime>='$today'].SnapshotId" \
    --output text)

if [ -z "$recent_snapshots" ]; then
    log "No recent snapshots found to copy"
    exit 0
fi

copied_count=0
for snapshot_id in $recent_snapshots; do
    log "Copying snapshot $snapshot_id to $TARGET_REGION"
    
    # Get snapshot description
    description=$(aws ec2 describe-snapshots \
        --snapshot-ids $snapshot_id \
        --region $SOURCE_REGION \
        --query 'Snapshots[0].Description' \
        --output text)
    
    # Copy snapshot to target region
    new_snapshot_id=$(aws ec2 copy-snapshot \
        --source-region $SOURCE_REGION \
        --source-snapshot-id $snapshot_id \
        --region $TARGET_REGION \
        --description "Cross-region copy: $description" \
        --tag-specifications "ResourceType=snapshot,Tags=[
            {Key=Name,Value=CrossRegion-Copy-$snapshot_id},
            {Key=SourceSnapshot,Value=$snapshot_id},
            {Key=SourceRegion,Value=$SOURCE_REGION},
            {Key=CreatedBy,Value=cross-region-backup},
            {Key=CopyDate,Value=$(date '+%Y-%m-%d %H:%M:%S')}
        ]" \
        --query 'SnapshotId' \
        --output text)
    
    log "Created copy: $new_snapshot_id in $TARGET_REGION"
    ((copied_count++))
done

log "Cross-region backup completed. Copied $copied_count snapshots"

# ================================================================
# scripts/backup-automation/backup-schedule.sh
#!/bin/bash
# Backup Schedule Manager Script
# Usage: ./backup-schedule.sh [setup|remove|status]

set -e

LOG_FILE="/var/log/backup-operations.log"
BACKUP_SCRIPT_PATH="/opt/xyz-backup"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

usage() {
    echo "Usage: $0 [setup|remove|status]"
    echo "  setup  - Install backup schedule"
    echo "  remove - Remove backup schedule"
    echo "  status - Show current schedule status"
    exit 1
}

setup_backup_schedule() {
    log "Setting up automated backup schedule"
    
    # Create backup directory
    sudo mkdir -p $BACKUP_SCRIPT_PATH
    
    # Copy backup scripts
    sudo cp scripts/backup-automation/*.sh $BACKUP_SCRIPT_PATH/
    sudo chmod +x $BACKUP_SCRIPT_PATH/*.sh
    
    # Create main backup script
    sudo tee $BACKUP_SCRIPT_PATH/daily-backup.sh > /dev/null << 'EOF'
#!/bin/bash
# Daily backup execution script

SCRIPT_DIR="/opt/xyz-backup"
LOG_FILE="/var/log/backup-operations.log"

# Create snapshots of all XYZ volumes
$SCRIPT_DIR/create-snapshots.sh --all us-east-1

# Cross-region backup
$SCRIPT_DIR/cross-region-backup.sh us-east-1 us-west-2

# Cleanup old snapshots (keep 7 days)
$SCRIPT_DIR/cleanup-old-snapshots.sh 7 us-east-1
$SCRIPT_DIR/cleanup-old-snapshots.sh 7 us-west-2

# Log completion
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daily backup completed" >> $LOG_FILE
EOF

    sudo chmod +x $BACKUP_SCRIPT_PATH/daily-backup.sh
    
    # Add to crontab (run daily at 2 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_SCRIPT_PATH/daily-backup.sh") | crontab -
    
    # Add weekly cleanup (run weekly on Sunday at 3 AM)
    (crontab -l 2>/dev/null; echo "0 3 * * 0 $BACKUP_SCRIPT_PATH/cleanup-old-snapshots.sh 7 us-east-1") | crontab -
    
    log "Backup schedule installed successfully"
    log "Daily backups: 2:00 AM"
    log "Weekly cleanup: Sunday 3:00 AM"
}

remove_backup_schedule() {
    log "Removing automated backup schedule"
    
    # Remove from crontab
    crontab -l | grep -v "$BACKUP_SCRIPT_PATH" | crontab -
    
    log "Backup schedule removed"
}

show_status() {
    echo "Current Backup Schedule Status:"
    echo "==============================="
    
    if [ -d "$BACKUP_SCRIPT_PATH" ]; then
        echo "Backup scripts installed: YES"
        echo "Script directory: $BACKUP_SCRIPT_PATH"
        echo "Scripts available:"
        ls -la $BACKUP_SCRIPT_PATH/
        echo ""
    else
        echo "Backup scripts installed: NO"
    fi
    
    echo "Current cron jobs:"
    crontab -l 2>/dev/null | grep -E "(backup|snapshot)" || echo "No backup cron jobs found"
    
    echo ""
    echo "Recent backup activity:"
    tail -10 $LOG_FILE 2>/dev/null || echo "No backup log found"
}

# Main logic
case ${1:-status} in
    setup)
        setup_backup_schedule
        ;;
    remove)
        remove_backup_schedule
        ;;
    status)
        show_status
        ;;
    *)
        usage
        ;;
esac