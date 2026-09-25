# ------------------------------------------------------------------------------
# Backward-compatible output name
#
# The old component (aws-ia/ipam) exposed only `pool_configurations`. The input is
# now the flat `pools` map, so this re-exports the effective pools passed to the
# module (after RAM-principal resolution) under the old name.
# ------------------------------------------------------------------------------

output "pool_configurations" {
  description = "The effective `pools` map passed to the module, after account-map RAM-principal resolution. Preserved under the old component's output name."
  value       = local.pools
}

# ------------------------------------------------------------------------------
# IPAM
# ------------------------------------------------------------------------------

output "ipam_id" {
  description = "ID of the IPAM — the one created here, or `existing_ipam_id` when `create_ipam` is `false`."
  value       = module.ipam.ipam_id
}

output "ipam_arn" {
  description = "ARN of the IPAM created by this component. `null` when `create_ipam` is `false`."
  value       = module.ipam.ipam_arn
}

output "private_default_scope_id" {
  description = "ID of the IPAM's private default scope, which top-level pools land in unless they name another."
  value       = module.ipam.private_default_scope_id
}

output "public_default_scope_id" {
  description = "ID of the IPAM's public default scope. Read-only. `null` when `create_ipam` is `false`."
  value       = module.ipam.public_default_scope_id
}

output "default_resource_discovery_id" {
  description = "ID of the resource discovery IPAM creates alongside itself."
  value       = module.ipam.default_resource_discovery_id
}

output "default_resource_discovery_association_id" {
  description = "ID of the resource discovery association IPAM creates alongside itself."
  value       = module.ipam.default_resource_discovery_association_id
}

output "scope_count" {
  description = "Number of scopes on the IPAM, including the two default ones."
  value       = module.ipam.scope_count
}

# ------------------------------------------------------------------------------
# Scopes
# ------------------------------------------------------------------------------

output "scope_ids" {
  description = "Map from the keys of `scopes` to the ID of each created scope."
  value       = module.ipam.scope_ids
}

output "scope_arns" {
  description = "Map from the keys of `scopes` to the ARN of each created scope."
  value       = module.ipam.scope_arns
}

# ------------------------------------------------------------------------------
# Pools
# ------------------------------------------------------------------------------

output "pool_ids" {
  description = "Map from the keys of `pools` to the ID of each created pool, flattened across every depth tier. The primary interface for downstream consumers."
  value       = module.ipam.pool_ids
}

output "pool_names" {
  description = "Map from the keys of `pools` to the null-label ID generated for each pool."
  value       = module.ipam.pool_names
}

output "pool_arns" {
  description = "Map from the keys of `pools` to the ARN of each created pool."
  value       = module.ipam.pool_arns
}

output "pool_states" {
  description = "Map from the keys of `pools` to the state of each created pool."
  value       = module.ipam.pool_states
}

output "pool_cidrs" {
  description = "Map from the keys of `pools` to the list of CIDRs provisioned into that pool."
  value       = module.ipam.pool_cidrs
}

output "pool_scope_ids" {
  description = "Map from the keys of `pools` to the scope each pool was created in."
  value       = module.ipam.pool_scope_ids
}

output "pool_cidr_ids" {
  description = "Map from `<pool name>/<cidr name>` to the Terraform ID of each provisioned pool CIDR."
  value       = module.ipam.pool_cidr_ids
}

output "allocation_ids" {
  description = "Map from `<pool name>/<allocation name>` to the AWS allocation ID of each manual reservation."
  value       = module.ipam.allocation_ids
}

output "allocation_cidrs" {
  description = "Map from `<pool name>/<allocation name>` to the CIDR reserved by each manual reservation."
  value       = module.ipam.allocation_cidrs
}

# ------------------------------------------------------------------------------
# Resource discovery
# ------------------------------------------------------------------------------

output "resource_discovery_id" {
  description = "ID of the resource discovery created by this component. `null` when `create_resource_discovery` is `false`."
  value       = module.ipam.resource_discovery_id
}

output "resource_discovery_arn" {
  description = "ARN of the resource discovery created by this component. `null` when `create_resource_discovery` is `false`."
  value       = module.ipam.resource_discovery_arn
}

output "resource_discovery_association_ids" {
  description = "Map from the keys of `resource_discovery_associations` to the ID of each association."
  value       = module.ipam.resource_discovery_association_ids
}

# ------------------------------------------------------------------------------
# RAM sharing
# ------------------------------------------------------------------------------

output "ram_resource_share_arns" {
  description = "Map from the keys of `pools` that requested RAM sharing to the ARN of that pool's resource share."
  value       = module.ipam.ram_resource_share_arns
}

# ------------------------------------------------------------------------------
# Delegated administration
# ------------------------------------------------------------------------------

output "delegated_admin_account_id" {
  description = "ID of the account holding the IPAM delegation. `null` when `organization_admin_enabled` is `false`."
  value       = module.ipam_organization_admin.delegated_admin_account_id
}

# ------------------------------------------------------------------------------
# Whole-resource pass-throughs
#
# The scalar outputs above are the stable interface. These expose each managed
# resource in full, keyed the same way, so any attribute the scalars don't surface
# stays reachable.
# ------------------------------------------------------------------------------

output "ipam" {
  description = "The full `aws_vpc_ipam` resource created by the module (all attributes). `null` when `create_ipam` is `false`."
  value       = module.ipam.ipam
}

output "scopes" {
  description = "Map from the keys of `scopes` to the full `aws_vpc_ipam_scope` resource (all attributes)."
  value       = module.ipam.scopes
}

output "pools" {
  description = "Map from the keys of `pools` to the full `aws_vpc_ipam_pool` resource (all attributes)."
  value       = module.ipam.pools
}

output "pool_cidrs_detail" {
  description = "Map from `<pool name>/<cidr name>` to the full `aws_vpc_ipam_pool_cidr` resource (all attributes)."
  value       = module.ipam.pool_cidrs_detail
}

output "allocations" {
  description = "Map from `<pool name>/<allocation name>` to the full `aws_vpc_ipam_pool_cidr_allocation` resource (all attributes)."
  value       = module.ipam.allocations
}

output "resource_discovery" {
  description = "The full `aws_vpc_ipam_resource_discovery` resource created by the module. `null` when `create_resource_discovery` is `false`."
  value       = module.ipam.resource_discovery
}

output "resource_discovery_associations" {
  description = "Map from the keys of `resource_discovery_associations` to the full `aws_vpc_ipam_resource_discovery_association` resource (all attributes)."
  value       = module.ipam.resource_discovery_associations
}

output "ram_resource_shares" {
  description = "Map from the keys of `pools` that requested RAM sharing to the full `aws_ram_resource_share` resource (all attributes)."
  value       = module.ipam.ram_resource_shares
}

output "delegation" {
  description = "The full `aws_vpc_ipam_organization_admin_account` resource (all attributes). `null` when `organization_admin_enabled` is `false`."
  value       = module.ipam_organization_admin.delegation
}
