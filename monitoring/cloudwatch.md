## 📊 Monitoring Setup

### CloudWatch Metrics
```json
{
  "custom-metrics": {
    "EC2": ["CPUUtilization", "NetworkIn", "NetworkOut"],
    "EBS": ["VolumeReadOps", "VolumeWriteOps", "VolumeTotalReadTime"],
    "Custom": ["WebServerResponseTime", "DiskSpaceUtilization"]
  }
}
```

### Monitoring Dashboards
- **Infrastructure Dashboard**: EC2 health, EBS performance
- **Performance Dashboard**: Response times, I/O metrics
- **Cost Dashboard**: Resource utilization and spending

### Automated Alerts
```bash
# CloudWatch Alarms
- CPU > 80% for 5 minutes
- Disk space > 85%
- HTTP response time > 2 seconds
- Failed web requests > 5%
```

### Log Management
```bash
# Application Logs
/var/log/httpd/access_log    # Web server access
/var/log/httpd/error_log     # Web server errors
/var/log/messages            # System logs
```

---