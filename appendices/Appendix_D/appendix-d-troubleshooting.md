## Appendix D: Troubleshooting Guide

### E.1 Common Issues and Solutions

**Issue 1: AMI Copy Failure**
```
Problem: Cross-region AMI copy fails or takes excessive time
Symptoms: Copy operation stuck at 0% or times out
Solution: 
1. Verify source AMI is in available state
2. Check IAM permissions for cross-region operations
3. Ensure destination region has sufficient capacity
4. Retry during off-peak hours

Commands:
aws ec2 describe-images --image-ids ami-12345678
aws ec2 copy-image --source-image-id ami-12345678 --source-region us-east-1 --region us-west-2
```

**Issue 2: EBS Volume Mount Failures**
```
Problem: EBS volume not mounting after attachment
Symptoms: Volume shows as attached but not accessible
Solution:
1. Check device naming (/dev/xvdf vs /dev/nvme1n1)
2. Create filesystem if volume is new
3. Verify mount point permissions

Commands:
lsblk                                    # List block devices
sudo mkfs -t ext4 /dev/xvdf             # Create filesystem
sudo mount /dev/xvdf /data1             # Mount volume
```

### E.2 Validation Checklist

**Pre-Deployment Checklist:**
- [ ] AWS CLI configured with proper credentials
- [ ] IAM permissions for EC2, EBS, and AMI operations
- [ ] VPC and subnet configuration verified
- [ ] Security groups properly configured
- [ ] SSH key pair available

**Post-Deployment Checklist:**
- [ ] EC2 instances running in both regions
- [ ] Web servers responding to HTTP requests
- [ ] EBS volumes attached and mounted
- [ ] Custom AMI created and replicated
- [ ] Snapshots created successfully
- [ ] Security groups allowing required traffic