## Appendix A: Configuration Files

### A.1 Security Group Configuration
```json
{
  "GroupName": "XYZ-Corp-WebServer-SG",
  "Description": "Security group for XYZ Corporation web servers",
  "VpcId": "vpc-12345678",
  "SecurityGroupRules": [
    {
      "IpProtocol": "tcp",
      "FromPort": 22,
      "ToPort": 22,
      "CidrIp": "203.0.113.0/24",
      "Description": "SSH access from corporate network"
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 80,
      "ToPort": 80,
      "CidrIp": "0.0.0.0/0",
      "Description": "HTTP access from internet"
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 443,
      "ToPort": 443,
      "CidrIp": "0.0.0.0/0",
      "Description": "HTTPS access from internet"
    }
  ]
}
```

### A.2 EC2 Launch Configuration
```json
{
  "ImageId": "ami-0abcdef1234567890",
  "InstanceType": "t3.micro",
  "KeyName": "xyz-corp-keypair",
  "SecurityGroupIds": ["sg-12345678"],
  "SubnetId": "subnet-12345678",
  "UserData": "base64-encoded-script",
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "XYZ-Corp-WebServer-East"},
        {"Key": "Environment", "Value": "Production"},
        {"Key": "Project", "Value": "Multi-Region-Infrastructure"}
      ]
    }
  ]
}
```

### A.3 EBS Volume Specifications
```json
{
  "VolumeType": "gp3",
  "Size": 16,
  "AvailabilityZone": "us-east-1a",
  "Encrypted": true,
  "Iops": 3000,
  "Throughput": 125,
  "TagSpecifications": [
    {
      "ResourceType": "volume",
      "Tags": [
        {"Key": "Name", "Value": "XYZ-Corp-Data-Volume"},
        {"Key": "Backup", "Value": "Required"},
        {"Key": "Environment", "Value": "Production"}
      ]
    }
  ]
}
```

### A.4 Apache Configuration
```apache
# /etc/httpd/conf/httpd.conf - Key modifications
ServerName xyz-corporation.local
DocumentRoot "/var/www/html"
DirectoryIndex index.html

<Directory "/var/www/html">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
```