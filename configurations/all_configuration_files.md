# Configuration Files Documentation

This document contains all configuration files used in the XYZ Corporation Multi-Region Web Server Infrastructure project.

## Table of Contents
- [AWS CLI Configuration](#aws-cli-configuration)
- [AMI Configuration](#ami-configuration)
- [Instance Configuration](#instance-configuration)
- [Backup Policies](#backup-policies)
- [Monitoring Configuration](#monitoring-configuration)
- [Security Groups](#security-groups)
- [Deployment Configuration](#deployment-configuration)
- [Cost Optimization](#cost-optimization)

---

## AWS CLI Configuration

### `configurations/aws-cli/config`
```ini
[default]
region = us-east-1
output = json

[profile xyz-primary]
region = us-east-1
output = table

[profile xyz-secondary]
region = us-west-2
output = table
```

### `configurations/aws-cli/credentials.template`
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY

[xyz-primary]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
region = us-east-1

[xyz-secondary]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
region = us-west-2
```

> **⚠️ Security Note**: Never commit actual credentials to version control. Use the template file and populate with actual values locally.

---

## AMI Configuration

### `configurations/ami-configs/web-server-ami.json`
```json
{
  "ami_configuration": {
    "name": "XYZ-Corp-WebServer",
    "description": "Custom web server AMI for XYZ Corporation",
    "base_ami": "ami-0abcdef1234567890",
    "instance_type": "t3.micro",
    "region": "us-east-1",
    "tags": {
      "Name": "XYZ-Corp-WebServer-v1.0",
      "Environment": "Production",
      "Owner": "XYZ Corporation",
      "Project": "Multi-Region Infrastructure",
      "Created": "2024-01-01"
    },
    "software_packages": [
      "httpd",
      "htop",
      "tree",
      "wget",
      "curl",
      "unzip",
      "amazon-cloudwatch-agent"
    ],
    "configurations": {
      "apache": {
        "server_tokens": "Prod",
        "server_signature": "Off",
        "security_headers": true,
        "compression": true
      },
      "monitoring": {
        "cloudwatch_agent": true,
        "custom_monitoring": true
      },
      "security": {
        "auto_updates": true,
        "log_rotation": true,
        "firewall": false
      }
    }
  },
  "cross_region_replication": {
    "enabled": true,
    "target_regions": ["us-west-2"],
    "naming_convention": "{name}-{region}",
    "copy_tags": true
  }
}
```

---

## Instance Configuration

### Primary Server: `configurations/instance-configs/primary-server.yaml`
```yaml
primary_server:
  region: us-east-1
  availability_zone: us-east-1a
  instance_type: t3.micro
  ami_id: ami-0abcdef1234567890
  key_pair: xyz-keypair-east
  
  security_groups:
    - name: XYZ-WebServer-SG
      description: Security group for XYZ Corporation web servers
      rules:
        inbound:
          - protocol: tcp
            port: 80
            cidr: 0.0.0.0/0
            description: HTTP access
          - protocol: tcp
            port: 443
            cidr: 0.0.0.0/0
            description: HTTPS access
          - protocol: tcp
            port: 22
            cidr: YOUR_IP/32
            description: SSH access
        outbound:
          - protocol: -1
            port: -1
            cidr: 0.0.0.0/0
            description: All outbound traffic

  ebs_volumes:
    root:
      size: 8
      type: gp3
      encrypted: true
      delete_on_termination: true
    data1:
      size: 8
      type: gp3
      encrypted: true
      mount_point: /data1
      device: /dev/sdf
    data2:
      size: 8
      type: gp3
      encrypted: true
      mount_point: /data2
      device: /dev/sdg

  tags:
    Name: XYZ-Primary-WebServer
    Environment: Production
    Region: Primary
    Owner: XYZ Corporation
    Project: Multi-Region Infrastructure
    Backup: Enabled
    Monitoring: Enabled

  monitoring:
    detailed_monitoring: true
    cloudwatch_logs: true
    custom_metrics: true
    
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention_days: 7
    cross_region_copy: true
```

### Secondary Server: `configurations/instance-configs/secondary-server.yaml`
```yaml
secondary_server:
  region: us-west-2
  availability_zone: us-west-2a
  instance_type: t3.micro
  ami_id: ami-copied-from-primary
  key_pair: xyz-keypair-west
  
  security_groups:
    - name: XYZ-WebServer-SG-West
      description: Security group for XYZ Corporation web servers - West
      rules:
        inbound:
          - protocol: tcp
            port: 80
            cidr: 0.0.0.0/0
            description: HTTP access
          - protocol: tcp
            port: 443
            cidr: 0.0.0.0/0
            description: HTTPS access
          - protocol: tcp
            port: 22
            cidr: YOUR_IP/32
            description: SSH access
        outbound:
          - protocol: -1
            port: -1
            cidr: 0.0.0.0/0
            description: All outbound traffic

  ebs_volumes:
    root:
      size: 8
      type: gp3
      encrypted: true
      delete_on_termination: true
    data1:
      size: 8
      type: gp3
      encrypted: true
      mount_point: /data1
      device: /dev/sdf

  tags:
    Name: XYZ-Secondary-WebServer
    Environment: Production
    Region: Secondary
    Owner: XYZ Corporation
    Project: Multi-Region Infrastructure
    Backup: Enabled
    Monitoring: Enabled

  monitoring:
    detailed_monitoring: true
    cloudwatch_logs: true
    custom_metrics: true
    
  backup:
    enabled: true
    schedule: "0 3 * * *"
    retention_days: 7
    source_region_sync: true
```

---

## Backup Policies

### `configurations/backup-policies/backup-policy.json`
```json
{
  "backup_policy": {
    "name": "XYZ-Corporation-Backup-Policy",
    "description": "Comprehensive backup policy for XYZ Corporation infrastructure",
    "version": "1.0",
    "schedules": {
      "daily": {
        "frequency": "daily",
        "time": "02:00",
        "timezone": "UTC",
        "retention_days": 7,
        "enabled": true
      },
      "weekly": {
        "frequency": "weekly",
        "day": "sunday",
        "time": "03:00",
        "timezone": "UTC",
        "retention_weeks": 4,
        "enabled": true
      },
      "monthly": {
        "frequency": "monthly",
        "day": 1,
        "time": "04:00",
        "timezone": "UTC",
        "retention_months": 12,
        "enabled": true
      }
    },
    "targets": {
      "volumes": {
        "include_patterns": ["XYZ-*"],
        "exclude_patterns": ["temp-*", "test-*"],
        "regions": ["us-east-1", "us-west-2"]
      },
      "instances": {
        "include_tags": {
          "Backup": "Enabled",
          "Owner": "XYZ Corporation"
        },
        "regions": ["us-east-1", "us-west-2"]
      }
    },
    "cross_region": {
      "enabled": true,
      "source_regions": ["us-east-1"],
      "target_regions": ["us-west-2"],
      "delay_hours": 1
    },
    "notifications": {
      "success": {
        "enabled": false,
        "sns_topic": "arn:aws:sns:us-east-1:123456789012:backup-success"
      },
      "failure": {
        "enabled": true,
        "sns_topic": "arn:aws:sns:us-east-1:123456789012:backup-failure"
      }
    }
  }
}
```

---

## Monitoring Configuration

### `configurations/monitoring/cloudwatch-config.json`
```json
{
  "cloudwatch_configuration": {
    "agent": {
      "metrics": {
        "namespace": "XYZ/Infrastructure",
        "metrics_collected": {
          "cpu": {
            "measurement": [
              "cpu_usage_idle",
              "cpu_usage_iowait",
              "cpu_usage_user",
              "cpu_usage_system"
            ],
            "metrics_collection_interval": 60,
            "totalcpu": false
          },
          "disk": {
            "measurement": ["used_percent"],
            "metrics_collection_interval": 60,
            "resources": ["*"]
          },
          "diskio": {
            "measurement": [
              "io_time",
              "read_bytes",
              "write_bytes",
              "reads",
              "writes"
            ],
            "metrics_collection_interval": 60,
            "resources": ["*"]
          },
          "mem": {
            "measurement": ["mem_used_percent"],
            "metrics_collection_interval": 60
          },
          "netstat": {
            "measurement": [
              "tcp_established",
              "tcp_time_wait"
            ],
            "metrics_collection_interval": 60
          },
          "swap": {
            "measurement": ["swap_used_percent"],
            "metrics_collection_interval": 60
          }
        }
      },
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/httpd/access_log",
                "log_group_name": "/xyz/apache/access",
                "log_stream_name": "{instance_id}",
                "timestamp_format": "%d/%b/%Y:%H:%M:%S %z"
              },
              {
                "file_path": "/var/log/httpd/error_log",
                "log_group_name": "/xyz/apache/error",
                "log_stream_name": "{instance_id}",
                "timestamp_format": "%a %b %d %H:%M:%S %Y"
              },
              {
                "file_path": "/var/log/messages",
                "log_group_name": "/xyz/system/messages",
                "log_stream_name": "{instance_id}"
              }
            ]
          }
        }
      }
    },
    "alarms": {
      "cpu_high": {
        "metric_name": "CPUUtilization",
        "namespace": "AWS/EC2",
        "statistic": "Average",
        "period": 300,
        "evaluation_periods": 2,
        "threshold": 80,
        "comparison_operator": "GreaterThanThreshold",
        "alarm_description": "High CPU utilization"
      },
      "disk_space_high": {
        "metric_name": "DiskSpaceUtilization",
        "namespace": "System/Linux",
        "statistic": "Average",
        "period": 300,
        "evaluation_periods": 1,
        "threshold": 85,
        "comparison_operator": "GreaterThanThreshold",
        "alarm_description": "High disk space utilization"
      }
    }
  }
}
```

---

## Security Groups

### `configurations/security/security-groups.yaml`
```yaml
security_groups:
  primary_region:
    region: us-east-1
    groups:
      - name: XYZ-WebServer-SG
        description: Security group for XYZ Corporation web servers
        vpc_id: default
        rules:
          ingress:
            - protocol: tcp
              from_port: 80
              to_port: 80
              cidr_blocks: ["0.0.0.0/0"]
              description: HTTP access from anywhere
            - protocol: tcp
              from_port: 443
              to_port: 443
              cidr_blocks: ["0.0.0.0/0"]
              description: HTTPS access from anywhere
            - protocol: tcp
              from_port: 22
              to_port: 22
              cidr_blocks: ["YOUR_IP_ADDRESS/32"]
              description: SSH access from admin IP
          egress:
            - protocol: -1
              from_port: -1
              to_port: -1
              cidr_blocks: ["0.0.0.0/0"]
              description: All outbound traffic
        tags:
          Name: XYZ-WebServer-SG
          Environment: Production
          Region: Primary
          
  secondary_region:
    region: us-west-2
    groups:
      - name: XYZ-WebServer-SG-West
        description: Security group for XYZ Corporation web servers - West Region
        vpc_id: default
        rules:
          ingress:
            - protocol: tcp
              from_port: 80
              to_port: 80
              cidr_blocks: ["0.0.0.0/0"]
              description: HTTP access from anywhere
            - protocol: tcp
              from_port: 443
              to_port: 443
              cidr_blocks: ["0.0.0.0/0"]
              description: HTTPS access from anywhere
            - protocol: tcp
              from_port: 22
              to_port: 22
              cidr_blocks: ["YOUR_IP_ADDRESS/32"]
              description: SSH access from admin IP
          egress:
            - protocol: -1
              from_port: -1
              to_port: -1
              cidr_blocks: ["0.0.0.0/0"]
              description: All outbound traffic
        tags:
          Name: XYZ-WebServer-SG-West
          Environment: Production
          Region: Secondary
```

---

## Deployment Configuration

### `configurations/deployment/deployment-config.yaml`
```yaml
deployment_configuration:
  project:
    name: "XYZ Multi-Region Infrastructure"
    version: "1.0"
    owner: "XYZ Corporation"
    
  environments:
    production:
      primary_region: us-east-1
      secondary_region: us-west-2
      instance_type: t3.micro
      min_instances: 1
      max_instances: 1
      
  deployment_strategy:
    type: blue_green
    rollback_enabled: true
    health_check_grace_period: 300
    
  regions:
    us-east-1:
      name: "Primary Region"
      role: primary
      availability_zones:
        - us-east-1a
        - us-east-1b
      subnets:
        - subnet-12345678  # Replace with actual subnet ID
        - subnet-87654321  # Replace with actual subnet ID
        
    us-west-2:
      name: "Secondary Region"
      role: secondary
      availability_zones:
        - us-west-2a
        - us-west-2b
      subnets:
        - subnet-abcdef12  # Replace with actual subnet ID
        - subnet-fedcba21  # Replace with actual subnet ID
        
  automation:
    ami_creation:
      enabled: true
      schedule: "0 6 * * 1"  # Weekly on Monday at 6 AM
      cleanup_old_amis: true
      retention_count: 3
      
    cross_region_sync:
      enabled: true
      schedule: "0 7 * * 1"  # Weekly on Monday at 7 AM
      sync_delay_minutes: 30
      
    backup:
      enabled: true
      schedule: "0 2 * * *"  # Daily at 2 AM
      retention_policy: "7d"
      cross_region_copy: true
      
  monitoring:
    enabled: true
    detailed_monitoring: true
    log_retention_days: 30
    alert_email: "admin@xyzcorp.com"
    
  security:
    encryption_at_rest: true
    encryption_in_transit: true
    key_rotation_enabled: true
    compliance_logging: true
```

---

## Cost Optimization

### `configurations/cost-optimization/cost-config.yaml`
```yaml
cost_optimization:
  policies:
    instance_scheduling:
      enabled: false  # Keep instances running for production
      dev_schedule:
        start_time: "08:00"
        stop_time: "18:00"
        timezone: "UTC"
        weekdays_only: true
        
    right_sizing:
      enabled: true
      evaluation_period_days: 30
      cpu_threshold_low: 10
      memory_threshold_low: 20
      recommendations_enabled: true
      
    storage_optimization:
      enabled: true
      old_snapshot_cleanup:
        retention_days: 30
        automated: true
        exclude_tags: ["permanent", "critical"]
      unused_volume_detection: true
      gp2_to_gp3_migration: true
      
    reserved_instances:
      enabled: false  # Manual decision required
      recommendations: true
      commitment_level: "1_year"
      payment_option: "partial_upfront"
      
  budgets:
    monthly_limit: 100.00
    currency: "USD"
    alerts:
      - threshold: 80
        type: "percentage"
        notification: "admin@xyzcorp.com"
      - threshold: 95
        type: "percentage"
        notification: "admin@xyzcorp.com"
        
  tagging_strategy:
    required_tags:
      - "Owner"
      - "Environment"
      - "Project"
      - "CostCenter"
    cost_allocation_tags:
      - "Owner"
      - "Project"
      - "Environment"
      
  reporting:
    enabled: true
    frequency: "weekly"
    email_recipients: ["admin@xyzcorp.com"]
    include_recommendations: true
```

---

## Usage Instructions

### 1. Configuration Setup
```bash
# Replace placeholder values before using
sed -i 's/YOUR_ACCESS_KEY_ID/actual_key_id/g' configurations/aws-cli/credentials
sed -i 's/YOUR_IP_ADDRESS/your_actual_ip/g' configurations/security/security-groups.yaml
sed -i 's/ami-0abcdef1234567890/actual_ami_id/g' configurations/instance-configs/*.yaml
```

### 2. AWS CLI Profile Setup
```bash
# Copy configuration files
cp configurations/aws-cli/config ~/.aws/
cp configurations/aws-cli/credentials ~/.aws/

# Test profiles
aws ec2 describe-instances --profile xyz-primary
aws ec2 describe-instances --profile xyz-secondary
```

### 3. Deploy Using Configuration
```bash
# Create security groups
aws ec2 create-security-group --cli-input-yaml file://configurations/security/security-groups.yaml

# Launch instances with configuration
aws ec2 run-instances --cli-input-yaml file://configurations/instance-configs/primary-server.yaml
```

---

## Security Best Practices

- ✅ **Credentials Management**: Never commit actual AWS credentials
- ✅ **IP Restrictions**: SSH access limited to admin IP addresses  
- ✅ **Encryption**: All EBS volumes encrypted at rest
- ✅ **Minimal Access**: Security groups follow least privilege principle
- ✅ **Monitoring**: Comprehensive logging and alerting configured
- ✅ **Backup Strategy**: Multi-tier backup with cross-region replication

## Configuration Validation

Before deploying, validate configurations using:
```bash
# YAML syntax validation
python -c "import yaml; yaml.safe_load(open('config.yaml'))"

# JSON syntax validation  
python -m json.tool config.json

# AWS CLI dry-run validation
aws ec2 run-instances --dry-run --cli-input-yaml file://config.yaml
```