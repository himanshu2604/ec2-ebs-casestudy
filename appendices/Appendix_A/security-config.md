| Property | Value |
| --- | --- |
| Description | Security group for XYZ Corporation web servers |
| GroupName | XYZ-Corp-WebServer-SG |
| SecurityGroupRules | _complex array_ |
| VpcId | vpc-12345678 |

### SecurityGroupRules
| # | CidrIp| Description| FromPort| IpProtocol| ToPort|
| --- | --- | --- | --- | --- | --- |
| 1 | 203.0.113.0/24 | SSH access from corporate network | 22 | tcp | 22 |
| 2 | 0.0.0.0/0 | HTTP access from internet | 80 | tcp | 80 |
| 3 | 0.0.0.0/0 | HTTPS access from internet | 443 | tcp | 443 |