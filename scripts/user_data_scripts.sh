# scripts/user-data/web-server-init.sh
#!/bin/bash
# Web Server Initialization Script for XYZ Corporation
# Usage: Used as EC2 user data for automated web server setup

set -e  # Exit on any error

# Variables
LOG_FILE="/var/log/web-server-init.log"
WEB_ROOT="/var/www/html"
SERVER_NAME="XYZ Corporation Web Server"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "Starting web server initialization..."

# Update system
log "Updating system packages..."
yum update -y

# Install required packages
log "Installing web server and utilities..."
yum install -y httpd htop tree wget curl unzip

# Start and enable Apache
log "Starting Apache web server..."
systemctl start httpd
systemctl enable httpd

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo $AVAILABILITY_ZONE | sed 's/[a-z]$//')
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create custom index page
log "Creating custom web page..."
cat > $WEB_ROOT/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$SERVER_NAME</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            padding: 20px;
        }
        .header { 
            background: rgba(255,255,255,0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 40px; 
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        .header h1 { 
            color: #2c3e50; 
            margin: 0; 
            font-size: 2.5em;
            text-align: center;
        }
        .header p { 
            color: #7f8c8d; 
            text-align: center; 
            margin: 10px 0 0 0;
            font-size: 1.2em;
        }
        .server-info { 
            background: rgba(255,255,255,0.9);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 30px;
            margin: 20px 0;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .info-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            border-left: 4px solid #3498db;
        }
        .info-card h3 {
            color: #2c3e50;
            margin: 0 0 10px 0;
            font-size: 1.1em;
        }
        .info-card p {
            color: #7f8c8d;
            margin: 0;
            font-family: monospace;
            font-size: 0.9em;
        }
        .status {
            background: #2ecc71;
            color: white;
            padding: 10px 20px;
            border-radius: 25px;
            display: inline-block;
            margin: 20px 0;
            font-weight: bold;
        }
        .timestamp {
            text-align: center;
            color: #95a5a6;
            font-size: 0.9em;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>$SERVER_NAME</h1>
            <p>Multi-Region Secure Infrastructure</p>
            <div class="status">🟢 OPERATIONAL</div>
        </div>
        
        <div class="server-info">
            <h2>Server Information</h2>
            <div class="info-grid">
                <div class="info-card">
                    <h3>Instance ID</h3>
                    <p>$INSTANCE_ID</p>
                </div>
                <div class="info-card">
                    <h3>Region</h3>
                    <p>$REGION</p>
                </div>
                <div class="info-card">
                    <h3>Availability Zone</h3>
                    <p>$AVAILABILITY_ZONE</p>
                </div>
                <div class="info-card">
                    <h3>Public IP</h3>
                    <p>$PUBLIC_IP</p>
                </div>
            </div>
            
            <div class="info-card">
                <h3>Infrastructure Features</h3>
                <ul>
                    <li>Multi-Region Deployment (US-East-1 / US-West-2)</li>
                    <li>Dynamic EBS Storage Management</li>
                    <li>Automated Backup Strategy</li>
                    <li>Custom AMI Standardization</li>
                    <li>Cross-Region Disaster Recovery</li>
                </ul>
            </div>
        </div>
        
        <div class="timestamp">
            Server initialized: $(date '+%Y-%m-%d %H:%M:%S UTC')
        </div>
    </div>
</body>
</html>
EOF

# Create health check endpoint
log "Creating health check endpoint..."
cat > $WEB_ROOT/health << EOF
{
    "status": "healthy",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "instance_id": "$INSTANCE_ID",
    "region": "$REGION",
    "availability_zone": "$AVAILABILITY_ZONE"
}
EOF

# Create server info endpoint
log "Creating server info endpoint..."
cat > $WEB_ROOT/info << EOF
{
    "server_name": "$SERVER_NAME",
    "instance_id": "$INSTANCE_ID",
    "region": "$REGION",
    "availability_zone": "$AVAILABILITY_ZONE",
    "public_ip": "$PUBLIC_IP",
    "uptime": "$(uptime -p)",
    "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Configure Apache
log "Configuring Apache..."
sed -i 's/#ServerName www.example.com:80/ServerName localhost:80/' /etc/httpd/conf/httpd.conf

# Add custom Apache configuration
cat >> /etc/httpd/conf/httpd.conf << EOF

# Custom configuration for XYZ Corporation
ServerTokens Prod
ServerSignature Off

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"

# Enable compression
LoadModule deflate_module modules/mod_deflate.so
<Location />
    SetOutputFilter DEFLATE
    SetEnvIfNoCase Request_URI \
        \.(?:gif|jpe?g|png)$ no-gzip dont-vary
    SetEnvIfNoCase Request_URI \
        \.(?:exe|t?gz|zip|bz2|sit|rar)$ no-gzip dont-vary
</Location>
EOF

# Restart Apache to apply configuration
systemctl restart httpd

# Set up log rotation
log "Setting up log rotation..."
cat > /etc/logrotate.d/web-server-init << EOF
$LOG_FILE {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    create 644 root root
}
EOF

# Install CloudWatch agent (optional)
log "Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create a simple monitoring script
log "Creating monitoring script..."
cat > /opt/server-monitor.sh << 'EOF'
#!/bin/bash
# Simple server monitoring script

LOG_FILE="/var/log/server-monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# Check Apache status
if systemctl is-active --quiet httpd; then
    log "Apache is running"
else
    log "Apache is not running - attempting restart"
    systemctl start httpd
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    log "WARNING: Disk usage is ${DISK_USAGE}%"
fi

# Update server info
curl -s http://169.254.169.254/latest/meta-data/public-ipv4 > /tmp/current_ip
CURRENT_IP=$(cat /tmp/current_ip)
sed -i "s/\"public_ip\": \".*\"/\"public_ip\": \"$CURRENT_IP\"/" /var/www/html/info
sed -i "s/\"last_updated\": \".*\"/\"last_updated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" /var/www/html/info
EOF

chmod +x /opt/server-monitor.sh

# Add monitoring to crontab
echo "*/5 * * * * /opt/server-monitor.sh" | crontab -

# Final security hardening
log "Applying security hardening..."
chmod 644 $WEB_ROOT/index.html
chmod 644 $WEB_ROOT/health
chmod 644 $WEB_ROOT/info
chown -R apache:apache $WEB_ROOT

# Clean up
log "Cleaning up temporary files..."
rm -f /root/amazon-cloudwatch-agent.rpm
yum clean all

# Verify installation
log "Verifying installation..."
if curl -f http://localhost/ > /dev/null 2>&1; then
    log "Web server setup completed successfully"
    echo "SUCCESS: Web server is running and accessible"
else
    log "ERROR: Web server setup failed"
    echo "ERROR: Web server is not responding"
    exit 1
fi

log "Web server initialization completed successfully"
echo "Web server initialization completed at $(date)"