## Appendix C: Performance Benchmarks

### D.1 Response Time Analysis
```
Performance Test Results (Average over 10 requests):

US-East-1 Region:
├── Response Time: 45ms
├── Time to First Byte: 12ms
├── DNS Lookup: 2ms
├── TCP Connection: 8ms
└── Content Transfer: 23ms

US-West-2 Region:
├── Response Time: 52ms
├── Time to First Byte: 15ms
├── DNS Lookup: 3ms
├── TCP Connection: 12ms
└── Content Transfer: 22ms

Cross-Region Latency:
└── Average: 7ms difference (15.5% slower from West Coast)
```

### D.2 Storage Performance Metrics
```
EBS Volume Performance (gp3 16GB):

Read Operations:
├── Sequential Read: 125 MB/s
├── Random Read IOPS: 3,000
├── Read Latency: <1ms
└── Sustained Performance: 99.9%

Write Operations:
├── Sequential Write: 125 MB/s
├── Random Write IOPS: 3,000
├── Write Latency: <1ms
└── Sustained Performance: 99.9%

Volume Operations Timing:
├── Attach: 15-30 seconds
├── Detach: 10-15 seconds
├── Extend: 60-120 seconds
└── Snapshot: 120-300 seconds
```

### D.3 Cost Performance Analysis
```
Monthly Cost Breakdown by Component:

Infrastructure Costs:
├── EC2 US-East-1: $8.50 (39.4%)
├── EC2 US-West-2: $8.50 (39.4%)
├── EBS Storage: $1.60 (7.4%)
├── EBS Snapshots: $1.00 (4.6%)
└── Data Transfer: $2.00 (9.3%)

Cost Per Performance Metrics:
├── Cost per GB storage: $0.10/month
├── Cost per IOPS: $0.0053/month
├── Cost per region: $10.10/month
└── Total ROI vs Traditional: 98.3% savings
```