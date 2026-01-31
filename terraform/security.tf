# Cloud Armor Security Policy
resource "google_compute_security_policy" "policy" {
  count = var.enable_cloud_armor ? 1 : 0
  name  = "${var.resource_prefix}-security-policy"

  description = "Cloud Armor security policy with OWASP Top 10, rate limiting, and geo-filtering"

  # Rule 1: Rate limiting - General traffic
  rule {
    action   = "rate_based_ban"
    priority = 1000

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"

      enforce_on_key = "IP"

      rate_limit_threshold {
        count        = var.rate_limit_threshold
        interval_sec = 60
      }

      ban_duration_sec = 600
    }

    description = "Rate limit: ${var.rate_limit_threshold} requests per minute per IP"
  }

  # Rule 2: Rate limiting - Login endpoint (stricter)
  rule {
    action   = "rate_based_ban"
    priority = 1100

    match {
      expr {
        expression = "request.path.matches('/api/login') || request.path.matches('/login')"
      }
    }

    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"

      enforce_on_key = "IP"

      rate_limit_threshold {
        count        = 20
        interval_sec = 60
      }

      ban_duration_sec = 1800
    }

    description = "Strict rate limit for login endpoints: 20 req/min"
  }

  # Rule 3: OWASP ModSecurity Core Rule Set - SQL Injection (SQLi)
  rule {
    action   = "deny(403)"
    priority = 2000

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }

    description = "OWASP: Block SQL Injection attacks"
  }

  # Rule 4: OWASP ModSecurity Core Rule Set - Cross-Site Scripting (XSS)
  rule {
    action   = "deny(403)"
    priority = 2100

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }

    description = "OWASP: Block Cross-Site Scripting attacks"
  }

  # Rule 5: OWASP ModSecurity Core Rule Set - Local File Inclusion (LFI)
  rule {
    action   = "deny(403)"
    priority = 2200

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }

    description = "OWASP: Block Local File Inclusion attacks"
  }

  # Rule 6: OWASP ModSecurity Core Rule Set - Remote Code Execution (RCE)
  rule {
    action   = "deny(403)"
    priority = 2300

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }

    description = "OWASP: Block Remote Code Execution attacks"
  }

  # Rule 7: OWASP ModSecurity Core Rule Set - Remote File Inclusion (RFI)
  rule {
    action   = "deny(403)"
    priority = 2400

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }

    description = "OWASP: Block Remote File Inclusion attacks"
  }

  # Rule 8: OWASP ModSecurity Core Rule Set - Method Enforcement
  rule {
    action   = "deny(403)"
    priority = 2500

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('methodenforcement-v33-stable')"
      }
    }

    description = "OWASP: Block HTTP method enforcement violations"
  }

  # Rule 9: OWASP ModSecurity Core Rule Set - Scanner Detection
  rule {
    action   = "deny(403)"
    priority = 2600

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
      }
    }

    description = "OWASP: Block security scanners and bots"
  }

  # Rule 10: OWASP ModSecurity Core Rule Set - Protocol Attack
  rule {
    action   = "deny(403)"
    priority = 2700

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
      }
    }

    description = "OWASP: Block protocol attacks"
  }

  # Rule 11: OWASP ModSecurity Core Rule Set - PHP Injection
  rule {
    action   = "deny(403)"
    priority = 2800

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('php-v33-stable')"
      }
    }

    description = "OWASP: Block PHP injection attacks"
  }

  # Rule 12: OWASP ModSecurity Core Rule Set - Session Fixation
  rule {
    action   = "deny(403)"
    priority = 2900

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sessionfixation-v33-stable')"
      }
    }

    description = "OWASP: Block session fixation attacks"
  }

  # Rule 13: Geo-filtering (if countries are specified)
  dynamic "rule" {
    for_each = length(var.allowed_countries) > 0 ? [1] : []

    content {
      action   = "deny(403)"
      priority = 3000

      match {
        expr {
          expression = "![${join(", ", formatlist("'%s'", var.allowed_countries))}].contains(origin.region_code)"
        }
      }

      description = "Geo-filter: Allow only specified countries"
    }
  }

  # Rule 14: Block known malicious IPs (example - can be customized)
  rule {
    action   = "deny(403)"
    priority = 4000

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('cve-canary')"
      }
    }

    description = "Block known malicious IP addresses and CVE exploitation attempts"
  }

  # Default rule: Allow all other traffic
  rule {
    action   = "allow"
    priority = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"

      config {
        src_ip_ranges = ["*"]
      }
    }

    description = "Default rule: Allow all other legitimate traffic"
  }

  # Adaptive Protection (ML-based DDoS mitigation)
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable          = true
      rule_visibility = "STANDARD"
    }
  }
}
