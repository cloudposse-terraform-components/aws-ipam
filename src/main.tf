locals {
  enabled = module.this.enabled

  # `full_account_map` (account name -> 12-digit ID) from the `account-map`
  # component. Empty when disabled so the RAM-principal resolution below is inert
  # and never dereferences a remote state that was not read.
  full_account_map   = local.enabled ? module.account_map.outputs.full_account_map : {}
  current_account_id = local.enabled ? join("", data.aws_caller_identity.current[*].account_id) : ""

  # Preserve the old component's ergonomic: a RAM principal that matches an
  # `account-map` key is resolved to that account's ID; anything else (a literal
  # account ID, an OU ARN, or the whole-org ARN) passes through untouched. The
  # current account is dropped, because RAM cannot share a resource with its own
  # owner. Every other field of each pool is passed straight through to the module.
  pools = {
    for pool_key, pool in var.pools : pool_key => (
      pool.ram_share == null ? pool : merge(pool, {
        ram_share = merge(pool.ram_share, {
          principals = toset([
            for principal in coalesce(pool.ram_share.principals, toset([])) :
            lookup(local.full_account_map, principal, principal)
            if lookup(local.full_account_map, principal, principal) != local.current_account_id
          ])
        })
      })
    )
  }
}

data "aws_caller_identity" "current" {
  count = local.enabled ? 1 : 0
}

# Swap to the `1.x` registry version once CloudPosse cuts the release:
#   source  = "cloudposse/ipam/aws"
#   version = "1.x.x"
module "ipam" {
  source = "git::https://github.com/cloudposse/terraform-aws-ipam.git?ref=696edd05294f7d28256492d622ac316070cf04d6"

  create_ipam            = var.create_ipam
  existing_ipam_id       = var.existing_ipam_id
  existing_ipam_scope_id = var.existing_ipam_scope_id
  ipam_description       = var.ipam_description
  operating_regions      = var.operating_regions
  ipam_tier              = var.ipam_tier
  private_gua_enabled    = var.private_gua_enabled
  metered_account        = var.metered_account
  ipam_cascade_enabled   = var.ipam_cascade_enabled
  ipam_timeouts          = var.ipam_timeouts

  scopes = var.scopes

  pools              = local.pools
  pool_timeouts      = var.pool_timeouts
  pool_cidr_timeouts = var.pool_cidr_timeouts

  create_resource_discovery                         = var.create_resource_discovery
  resource_discovery_description                    = var.resource_discovery_description
  resource_discovery_operating_regions              = var.resource_discovery_operating_regions
  resource_discovery_organizational_unit_exclusions = var.resource_discovery_organizational_unit_exclusions
  resource_discovery_associations                   = var.resource_discovery_associations

  ram_share_permission_arns = var.ram_share_permission_arns

  context = module.this.context
}

# Delegated IPAM administration is an organization-wide singleton that must run in
# the management account, and its destroy revokes the delegation for the entire
# organization. It is intentionally a separate submodule; enable it only in a
# stack that targets the management account.
module "ipam_organization_admin" {
  source = "git::https://github.com/cloudposse/terraform-aws-ipam.git//modules/organization-admin?ref=696edd05294f7d28256492d622ac316070cf04d6"

  enabled = local.enabled && var.organization_admin_enabled

  # An account name resolves to its ID via `account-map`; a literal 12-digit ID
  # passes through. The placeholder is only ever seen when the submodule is
  # disabled (count 0), where it satisfies the submodule's non-null, 12-digit
  # validation without being used.
  delegated_admin_account_id = var.delegated_admin_account == null ? "000000000000" : lookup(
    local.full_account_map, var.delegated_admin_account, var.delegated_admin_account
  )

  context = module.this.context
}
