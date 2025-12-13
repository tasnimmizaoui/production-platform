┌────────────────────────────────────────┐
│ VPC (10.0.0.0/16)                      │
│                                        │
│  Public Subnet (10.0.1.0/24)           │
│  └── Internet Gateway (FREE)           │
│                                        │
│  Private Subnet (10.0.2.0/24)          │
│  └── K3s Cluster                       │
│      ├── API Service                   │
│      ├── Worker Service                │
│      └── Redis (in-cluster)            │
│                                        │
│  Infrastructure:                       │
│  ├── S3 VPC Endpoint (FREE)            │
│  ├── Flow Logs → S3 (FREE < 5GB)       │
│  └── Session Manager (FREE)            │
└────────────────────────────────────────┘

Monthly Cost: $0