variable "region" {
  type        = string
  description = "AWS Region"
}

variable "account_map_environment_name" {
  type        = string
  description = "The name of the environment where `account_map` is provisioned"
  default     = "gbl"
}

variable "account_map_stage_name" {
  type        = string
  description = "The name of the stage where `account_map` is provisioned"
  default     = "root"
}

variable "account_map_tenant_name" {
  type        = string
  description = <<-EOT
  The name of the tenant where `account_map` is provisioned.

  If the `tenant` label is not used, leave this as `null`.
  EOT
  default     = null
}

# ------------------------------------------------------------------------------
# IPAM
#
# The variables below mirror the `cloudposse/terraform-aws-ipam` module's input
# surface one-to-one. Override them from the catalog or stack; do not rename them.
# ------------------------------------------------------------------------------

variable "create_ipam" {
  type        = bool
  description = <<-EOT
    Whether to create an `aws_vpc_ipam`. Set to `false` to build pools inside an
    IPAM that already exists (for a second instance of this component in another
    Region, supply `existing_ipam_id` and `existing_ipam_scope_id`).
    EOT
  default     = true
  nullable    = false
}

variable "existing_ipam_id" {
  type        = string
  description = "ID of an existing `aws_vpc_ipam` to build against. Only consulted when `create_ipam` is `false`."
  default     = null
}

variable "existing_ipam_scope_id" {
  type        = string
  description = "ID of an existing IPAM scope that top-level pools default into. Required when `create_ipam` is `false` and a top-level pool does not resolve a scope of its own."
  default     = null
}

variable "ipam_description" {
  type        = string
  description = "Description for the IPAM. Defaults to the null-label ID. Only used when `create_ipam` is `true`."
  default     = null
}

variable "operating_regions" {
  type        = list(string)
  description = "Regions the IPAM may discover, monitor, and allocate from. Must include the Region the component is applied into at create time. When empty, the module registers just the current Region."
  default     = []
  nullable    = false
}

variable "ipam_tier" {
  type        = string
  description = "IPAM tier. Valid values: `free`, `advanced`. Leaving this `null` inherits the provider default of `advanced` (the billable tier)."
  default     = null
}

variable "private_gua_enabled" {
  type        = bool
  description = "Whether IPAM treats your own globally-unique IPv6 ranges (from `2000::/3`) as private address space. Maps to the provider's `enable_private_gua`."
  default     = null
}

variable "metered_account" {
  type        = string
  description = "Which account is metered for IPAM usage. Valid values: `ipam-owner`, `resource-owner`. `null` never produces a diff."
  default     = null
}

variable "ipam_cascade_enabled" {
  type        = bool
  description = "Whether to enable cascade delete on the IPAM. Delete-time only; on destroy it tears down every private scope, pool, and allocation, including address space in live use."
  default     = false
  nullable    = false
}

variable "ipam_timeouts" {
  type = object({
    create = optional(string, null)
    update = optional(string, null)
    delete = optional(string, null)
  })
  description = "Operation timeouts for the `aws_vpc_ipam` resource. `null` entries inherit the provider defaults of 3m each."
  default     = {}
  nullable    = false
}

# ------------------------------------------------------------------------------
# Scopes
# ------------------------------------------------------------------------------

variable "scopes" {
  type = map(object({
    description = optional(string, null)
    tags        = optional(map(string), {})
  }))
  description = <<-EOT
    Additional **private** IPAM scopes to create, keyed by name. Keys must be known
    at `plan` time. Public scopes cannot be created; consume the single public
    scope read-only through the `public_default_scope_id` output.
    EOT
  default     = {}
  nullable    = false
}

# ------------------------------------------------------------------------------
# Pools
#
# A flat map keyed by your own name for each pool. Hierarchy is expressed by a
# pool naming another entry as its `parent`, capped at a depth of 4. This replaces
# the old nested `pool_configurations`/`sub_pools` input.
#
# Component convenience: an entry in a pool's `ram_share.principals` that matches
# an `account-map` account name is resolved to that account's ID before it reaches
# the module; literal account IDs and ARNs pass through, and the current account
# is dropped.
# ------------------------------------------------------------------------------

variable "pools" {
  type = map(object({
    parent = optional(string, null)

    address_family = optional(string, "ipv4")
    locale         = optional(string, null)

    ipam_scope_id = optional(string, null)
    scope         = optional(string, null)

    aws_service      = optional(string, null)
    public_ip_source = optional(string, null)

    publicly_advertisable = optional(bool, null)

    source_resource = optional(object({
      resource_id     = string
      resource_owner  = string
      resource_region = string
      resource_type   = optional(string, "vpc")
    }), null)

    allocation_default_netmask_length = optional(number, null)
    allocation_max_netmask_length     = optional(number, null)
    allocation_min_netmask_length     = optional(number, null)
    allocation_resource_tags          = optional(map(string), {})
    auto_import                       = optional(bool, null)
    description                       = optional(string, null)

    cascade = optional(bool, false)

    tags = optional(map(string), {})

    cidrs = optional(map(object({
      cidr           = optional(string, null)
      netmask_length = optional(number, null)
      cidr_authorization_context = optional(object({
        message   = optional(string, null)
        signature = optional(string, null)
      }), null)
    })), {})

    allocations = optional(map(object({
      cidr             = optional(string, null)
      netmask_length   = optional(number, null)
      disallowed_cidrs = optional(set(string), null)
      description      = optional(string, null)
      tags             = optional(map(string), {})
    })), {})

    ram_share = optional(object({
      principals                = optional(set(string), [])
      allow_external_principals = optional(bool, false)
      permission_arns           = optional(set(string), null)
      tags                      = optional(map(string), {})
    }), null)
  }))
  description = <<-EOT
    IPAM pools to create, as a flat map keyed by your own name for each pool.
    Keys must be known at `plan` time. Hierarchy is expressed by naming another
    entry as a pool's `parent`; a pool with no `parent` is top-level. Nesting is
    capped at a depth of 4. Each pool's provisioned CIDRs nest under `cidrs`, its
    manual reservations under `allocations`, and its RAM sharing under `ram_share`.
    EOT
  default     = {}
  nullable    = false
}

variable "pool_timeouts" {
  type = object({
    create = optional(string, null)
    update = optional(string, null)
    delete = optional(string, null)
  })
  description = "Operation timeouts applied to every `aws_vpc_ipam_pool`. `null` entries inherit the provider defaults (35m create)."
  default     = {}
  nullable    = false
}

variable "pool_cidr_timeouts" {
  type = object({
    create = optional(string, null)
    delete = optional(string, null)
  })
  description = "Operation timeouts applied to every `aws_vpc_ipam_pool_cidr`. `null` entries inherit the provider defaults of create 10m and delete 32m. Do not lower the 32m delete."
  default     = {}
  nullable    = false
}

# ------------------------------------------------------------------------------
# Resource discovery
# ------------------------------------------------------------------------------

variable "create_resource_discovery" {
  type        = bool
  description = "Whether to create an `aws_vpc_ipam_resource_discovery`. Only needed for cross-account or cross-organization monitoring."
  default     = false
  nullable    = false
}

variable "resource_discovery_description" {
  type        = string
  description = "Description for the resource discovery. Defaults to the null-label ID. Only used when `create_resource_discovery` is `true`."
  default     = null
}

variable "resource_discovery_operating_regions" {
  type        = list(string)
  description = "Regions the resource discovery monitors. When empty, falls back to `operating_regions`, and then to the current Region. Must include the current Region at create time."
  default     = []
  nullable    = false
}

variable "resource_discovery_organizational_unit_exclusions" {
  type        = list(string)
  description = "AWS Organizations entity paths to exclude from discovery — Organizations IDs joined by `/`. End a path with `/*` to exclude all child OUs."
  default     = []
  nullable    = false
}

variable "resource_discovery_associations" {
  type = map(object({
    ipam_id                    = optional(string, null)
    ipam_resource_discovery_id = string
    tags                       = optional(map(string), {})
  }))
  description = "Resource discoveries to associate with this IPAM, keyed by name. Keys must be known at `plan` time. `ipam_id` defaults to this component's IPAM."
  default     = {}
  nullable    = false
}

# ------------------------------------------------------------------------------
# RAM sharing
# ------------------------------------------------------------------------------

variable "ram_share_permission_arns" {
  type        = list(string)
  description = "Default RAM permission ARNs applied to every pool share that does not set its own `permission_arns`. Leave empty to let RAM apply its default managed permission for IPAM pools."
  default     = []
  nullable    = false
}

# ------------------------------------------------------------------------------
# Delegated administration (organization-admin submodule)
#
# An organization-wide singleton that must run in the management account. Its
# destroy revokes IPAM delegation for the entire organization. Enable it only in a
# stack that targets the management account.
# ------------------------------------------------------------------------------

variable "organization_admin_enabled" {
  type        = bool
  description = "Whether to delegate IPAM administration to `delegated_admin_account` via the `organization-admin` submodule. Enable only in a stack that targets the management account."
  default     = false
  nullable    = false
}

variable "delegated_admin_account" {
  type        = string
  description = "Account to delegate IPAM administration to, as either an `account-map` account name (resolved to its ID) or a literal 12-digit account ID. Required when `organization_admin_enabled` is `true`."
  default     = null
}
