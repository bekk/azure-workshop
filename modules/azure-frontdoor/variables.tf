# Required variables
variable "unique_id" {
  description = "Unique identifier to be used in resource names (e.g., 'okp456')"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "origin_host_name" {
  description = "Host name of the origin (e.g., storage account primary web host)"
  type        = string
}

# Optional variables with defaults
variable "sku_name" {
  description = "SKU name for the Azure Front Door profile"
  type        = string
  default     = "Standard_AzureFrontDoor"
}

variable "origin_enabled" {
  description = "Whether the origin is enabled"
  type        = bool
  default     = true
}

variable "certificate_name_check_enabled" {
  description = "Whether certificate name check is enabled for the origin"
  type        = bool
  default     = false
}

variable "origin_host_header" {
  description = "Host header to send to the origin. If not provided, uses origin_host_name"
  type        = string
  default     = null
}

variable "http_port" {
  description = "HTTP port for the origin"
  type        = number
  default     = 80
}

variable "https_port" {
  description = "HTTPS port for the origin"
  type        = number
  default     = 443
}

variable "origin_priority" {
  description = "Priority of the origin"
  type        = number
  default     = 1
}

variable "origin_weight" {
  description = "Weight of the origin"
  type        = number
  default     = 1000
}

variable "health_probe_protocol" {
  description = "Protocol for health probe"
  type        = string
  default     = "Https"
}

variable "health_probe_interval" {
  description = "Interval in seconds for health probe"
  type        = number
  default     = 120
}

variable "health_probe_path" {
  description = "Path for health probe"
  type        = string
  default     = "/"
}

variable "health_probe_request_type" {
  description = "Request type for health probe"
  type        = string
  default     = "GET"
}

variable "supported_protocols" {
  description = "Supported protocols for the route"
  type        = list(string)
  default     = ["Http", "Https"]
}

variable "https_redirect_enabled" {
  description = "Whether HTTPS redirect is enabled"
  type        = bool
  default     = true
}

variable "patterns_to_match" {
  description = "Patterns to match for the route"
  type        = list(string)
  default     = ["/*"]
}

variable "forwarding_protocol" {
  description = "Protocol for forwarding requests"
  type        = string
  default     = "MatchRequest"
}

variable "link_to_default_domain" {
  description = "Whether to link to the default domain"
  type        = bool
  default     = true
}

variable "cache_query_string_caching_behavior" {
  description = "Query string caching behavior"
  type        = string
  default     = "IgnoreQueryString"
}

# Custom domain variables (optional)
variable "enable_custom_domain" {
  description = "Whether to create a custom domain with automatic CNAME record creation"
  type        = bool
  default     = false
}

variable "custom_domain_host_name" {
  description = "Host name for the custom domain. If not provided, will be auto-generated from CNAME record"
  type        = string
  default     = null
}

variable "tls_certificate_type" {
  description = "TLS certificate type for custom domain"
  type        = string
  default     = "ManagedCertificate"
}

variable "tls_minimum_version" {
  description = "Minimum TLS version for custom domain"
  type        = string
  default     = "TLS12"
}

# DNS record variables (optional)
variable "cname_record_ttl" {
  description = "TTL for the CNAME record"
  type        = number
  default     = 60
}

# DNS validation variables (optional)
variable "create_validation_record" {
  description = "Whether to create DNS validation record for custom domain"
  type        = bool
  default     = true
}

variable "dns_zone_name" {
  description = "DNS zone name for CNAME and validation records (required if enable_custom_domain is true)"
  type        = string
  default     = null
}

variable "dns_zone_resource_group_name" {
  description = "Resource group name of the DNS zone (required if enable_custom_domain is true)"
  type        = string
  default     = null
}

variable "dns_validation_record_ttl" {
  description = "TTL for the DNS validation record"
  type        = number
  default     = 60
}