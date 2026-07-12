# Security Architecture

Comprehensive guide to designing secure infrastructure with zero trust, defense in depth, and threat modeling.

## Security Principles

### 1. Zero Trust Architecture

**"Never trust, always verify"**

```
Traditional: Trust inside network
Zero Trust: Verify every request, regardless of source
```

**Core Principles:**
- Verify explicitly (authenticate + authorize every request)
- Least privilege access
- Assume breach (isolate, detect, respond)

**Implementation:**
```yaml
# Every service verifies JWT, even internal
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  action: DENY
  rules:
  - from:
    - source:
        notRequestPrincipals: ["*"]  # Deny if no JWT
```

---

### 2. Defense in Depth

**Multiple security layers:**

```
┌─────────────────────────────────────────┐
│ Layer 7: Application (Auth, Input Validation)
│ Layer 6: API Gateway (Rate Limiting, WAF)
│ Layer 5: Service Mesh (mTLS, RBAC)
│ Layer 4: Network (Security Groups, NACLs)
│ Layer 3: Encryption (TLS, At-Rest)
│ Layer 2: Identity (IAM, OIDC)
│ Layer 1: Physical (Data Center Security)
└─────────────────────────────────────────┘
```

**If one layer breached, others still protect**

---

### 3. Least Privilege Access

```
Grant minimum permissions necessary

❌ Bad: Full admin access for all engineers
✅ Good: Read-only by default, elevated access via time-limited approvals
```

```yaml
# IAM policy: Least privilege
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::app-logs/*",
        "arn:aws:s3:::app-logs"
      ]
    }
  ]
}
# No write, no delete, only specific bucket
```

---

## Authentication & Authorization

### Authentication (Who are you?)

**OAuth 2.0 + OpenID Connect:**
```typescript
// JWT-based authentication
import jwt from 'jsonwebtoken';

function authenticateRequest(req) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) throw new UnauthorizedError();

  try {
    const payload = jwt.verify(token, process.env.JWT_PUBLIC_KEY, {
      algorithms: ['RS256'],
      issuer: 'https://auth.example.com',
      audience: 'api.example.com'
    });

    return payload;  // { sub: 'user-123', exp: ..., iat: ... }
  } catch (error) {
    throw new UnauthorizedError('Invalid token');
  }
}
```

**mTLS (Mutual TLS):**
```yaml
# Service-to-service authentication
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT  # Require mTLS for all traffic
```

---

### Authorization (What can you do?)

**RBAC (Role-Based Access Control):**
```typescript
// Express middleware
function requireRole(role: string) {
  return (req, res, next) => {
    if (!req.user.roles.includes(role)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}

app.delete('/users/:id', requireRole('admin'), deleteUser);
app.get('/users/:id', requireRole('user'), getUser);
```

**ABAC (Attribute-Based Access Control):**
```typescript
// Policy-based authorization
function canAccessResource(user, resource) {
  // Check attributes: user department, resource classification, time of day
  return user.department === resource.department &&
         user.clearanceLevel >= resource.classificationLevel &&
         isBusinessHours();
}
```

---

## Network Security

### VPC Design

```
┌─────────────────── VPC ───────────────────┐
│ Public Subnet (DMZ)                        │
│   - Load Balancer (internet-facing)       │
│   - NAT Gateway                            │
│                                            │
│ Private Subnet (Application)              │
│   - Application Servers (no public IP)    │
│   - Can reach internet via NAT            │
│                                            │
│ Private Subnet (Database)                 │
│   - Database (isolated)                   │
│   - No internet access                    │
└────────────────────────────────────────────┘
```

```terraform
# Security group: Database only accessible from app tier
resource "aws_security_group" "database" {
  name = "database-sg"

  # Only allow PostgreSQL from application tier
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  # No outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]  # Only VPC
  }
}
```

---

### WAF (Web Application Firewall)

```terraform
# AWS WAF rules
resource "aws_wafv2_web_acl" "main" {
  name  = "api-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Block SQL injection
  rule {
    name     = "block-sqli"
    priority = 1

    statement {
      sqli_match_statement {
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
      }
    }

    action {
      block {}
    }
  }

  # Rate limiting
  rule {
    name     = "rate-limit"
    priority = 2

    statement {
      rate_based_statement {
        limit              = 2000  # Per IP
        aggregate_key_type = "IP"
      }
    }

    action {
      block {}
    }
  }
}
```

---

## Encryption

### At Rest

```terraform
# RDS encryption
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
}

# S3 encryption
resource "aws_s3_bucket" "uploads" {
  bucket = "user-uploads"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

# EBS encryption
resource "aws_ebs_volume" "data" {
  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn
}
```

---

### In Transit

```yaml
# TLS 1.3 only
apiVersion: v1
kind: Service
metadata:
  name: api
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
    service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "arn:aws:acm:..."
    service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy: "ELBSecurityPolicy-TLS-1-2-2017-01"
```

---

## Secrets Management

**Never hardcode secrets:**

```typescript
// ❌ BAD
const dbPassword = 'mypassword123';

// ✅ GOOD - Environment variable
const dbPassword = process.env.DATABASE_PASSWORD;

// ✅ BETTER - Secrets manager
import { SecretsManager } from '@aws-sdk/client-secrets-manager';

const secrets = new SecretsManager({ region: 'us-east-1' });
const secret = await secrets.getSecretValue({ SecretId: 'prod/db/password' });
const dbPassword = JSON.parse(secret.SecretString).password;
```

**Kubernetes Secrets with External Secrets Operator:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: app-secrets
  data:
  - secretKey: DATABASE_PASSWORD
    remoteRef:
      key: prod/db/password
      property: password
```

---

## Threat Modeling

### STRIDE Framework

```
Spoofing       → Authentication
Tampering      → Integrity
Repudiation    → Logging/Audit
Info Disclosure → Encryption
Denial of Service → Rate Limiting
Elevation of Privilege → Authorization
```

**Example Threat Model:**
```markdown
# Threat: SQL Injection

## Description
Attacker injects malicious SQL via API input

## Attack Vector
POST /users with payload: { "name": "'; DROP TABLE users;--" }

## Impact
Data loss, unauthorized access

## Mitigations
1. Parameterized queries (Prisma ORM) ✅
2. Input validation ✅
3. WAF rules ✅
4. Least privilege DB user ✅

## Residual Risk
LOW (multiple layers)
```

---

## Security Monitoring

### Audit Logging

```typescript
// Log all security events
logger.info('Authentication success', {
  userId: user.id,
  ipAddress: req.ip,
  userAgent: req.headers['user-agent'],
  timestamp: new Date().toISOString()
});

logger.warn('Failed login attempt', {
  email: req.body.email,
  ipAddress: req.ip,
  reason: 'Invalid password',
  timestamp: new Date().toISOString()
});
```

**CloudTrail (AWS):**
```terraform
resource "aws_cloudtrail" "main" {
  name                          = "security-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

---

### Intrusion Detection

```yaml
# Falco: Runtime security for Kubernetes
- rule: Unexpected outbound connection
  desc: Detect pod making unexpected external connections
  condition: >
    outbound and
    not proc.name in (known_processes) and
    fd.rip != "0.0.0.0"
  output: >
    Unexpected outbound connection
    (pod=%k8s.pod.name ip=%fd.rip port=%fd.rport)
  priority: WARNING
```

---

## Compliance & Frameworks

### SOC 2 Requirements

- Access controls (RBAC)
- Encryption (at rest, in transit)
- Audit logging
- Incident response plan
- Vulnerability management
- Change management

### PCI-DSS (Payment Card)

- Network segmentation
- Strong authentication (MFA)
- Regular security testing
- Logging and monitoring
- Encryption of cardholder data

### HIPAA (Healthcare)

- PHI encryption
- Access controls
- Audit logs
- Breach notification procedures
- Business associate agreements

---

## Security Checklist

**Infrastructure:**
- [ ] VPC with private subnets
- [ ] Security groups (least privilege)
- [ ] Encryption at rest (KMS)
- [ ] Encryption in transit (TLS 1.3+)
- [ ] WAF enabled
- [ ] DDoS protection (CloudFront, Shield)

**Application:**
- [ ] Authentication (OAuth 2.0 / OIDC)
- [ ] Authorization (RBAC/ABAC)
- [ ] Input validation
- [ ] Parameterized queries (no SQL injection)
- [ ] CSRF protection
- [ ] Rate limiting
- [ ] Security headers (CSP, HSTS, etc.)

**Secrets:**
- [ ] No hardcoded secrets
- [ ] Secrets manager (Vault, AWS SM)
- [ ] Secret rotation enabled
- [ ] Least privilege IAM roles

**Monitoring:**
- [ ] Audit logging enabled
- [ ] CloudTrail / equivalent
- [ ] Intrusion detection (Falco, GuardDuty)
- [ ] Vulnerability scanning (Trivy, Snyk)
- [ ] Incident response plan

---

## Best Practices

✅ **Shift left** - Security in design phase
✅ **Automate** - Security scanning in CI/CD
✅ **Least privilege** - Grant minimal permissions
✅ **Defense in depth** - Multiple layers
✅ **Encrypt everything** - At rest + in transit
✅ **Zero trust** - Verify every request
✅ **Monitor continuously** - Detect anomalies
✅ **Patch regularly** - Keep dependencies updated

## Anti-Patterns

❌ **Security by obscurity** - Hiding secrets in code
❌ **Single point of failure** - No defense in depth
❌ **Ignoring CVEs** - Outdated dependencies
❌ **No logging** - Can't detect breaches
❌ **Overprivileged** - Admin access for all
❌ **Unencrypted data** - Plaintext sensitive data

---

**Related Resources:**
- devsecops/security-scanning.md - SAST, DAST, SCA
- devsecops/secrets-management.md - Vault, rotation
- devsecops/zero-trust-architecture.md - Deep dive
