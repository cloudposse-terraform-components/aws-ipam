# Migration: `pool_configurations` (aws-ia) → flat `pools` (cloudposse/terraform-aws-ipam)

This is a **breaking change**. The component was rewritten from the
`aws-ia/ipam/aws` module (nested `pool_configurations` / `sub_pools`) onto the
[`cloudposse/terraform-aws-ipam`](https://github.com/cloudposse/terraform-aws-ipam)
module, which takes a **flat `pools` map** keyed by your own name for each pool,
with hierarchy expressed by a pool naming another entry as its `parent`.

Because the underlying module changed, **every Terraform address changes**. A
straight upgrade would plan to destroy and recreate the IPAM, its pools, CIDRs,
and RAM shares. Use `moved` blocks (below) to re-home existing state instead.

## Input mapping

| Old (aws-ia wrapper) | New (this component) |
|---|---|
| `pool_configurations` (nested map, `sub_pools`) | `pools` (flat map; child names a `parent`) |
| `top_cidr` / `top_name` / `top_description` / `top_locale` | a top-level entry in `pools` (no `parent`) with `cidrs`, `description`, `locale` |
| `top_netmask_length` | `pools.<name>.cidrs.<key>.netmask_length` |
| `top_public_ip_source` / `top_aws_service` / `top_publicly_advertisable` | `pools.<name>.public_ip_source` / `.aws_service` / `.publicly_advertisable` |
| `<pool>.cidr` (list) | `pools.<name>.cidrs` (map of `{ cidr }` or `{ netmask_length }`) |
| `<pool>.ram_share_principals` | `pools.<name>.ram_share.principals` |
| `<pool>.allocation_*_netmask_length` | `pools.<name>.allocation_*_netmask_length` (unchanged names) |
| `<pool>.allocation_resource_tags` | `pools.<name>.allocation_resource_tags` |
| `create_ipam` | `create_ipam` (unchanged) |
| `ipam_id` (bind existing) | `existing_ipam_id` |
| `ipam_scope_id` (bind existing) | `existing_ipam_scope_id` |
| `ipam_scope_type: "private" \| "public"` | removed — a pool inherits the bound scope; name an additional private scope in `scopes`, or set `public_ip_source`/`aws_service` for a public pool |

## Output renames

| Old output | New output |
|---|---|
| `pool_ids."<parent>/<child>"` (path keys) | `pool_ids.<name>` (flat keys — your `pools` keys) |
| `pool_configurations.<pool>.cidr` | `pool_cidrs.<pool>` (list of provisioned CIDRs) |
| `organization_scope_id` | `private_default_scope_id` |
| `public_scope_id` | `public_default_scope_id` |

Downstream components that read these via remote state must be updated to the new
names/keys in the same change.

## Example: before → after

**Before** (aws-ia):

```yaml
top_cidr: ["10.0.0.0/16"]
top_name: "root"
pool_configurations:
  prod:
    cidr: ["10.0.0.0/16"]
    locale: "us-east-1"
    sub_pools:
      workload:
        cidr: ["10.0.128.0/17", "10.0.64.0/18"]
        locale: "us-east-1"
        allocation_default_netmask_length: 22
        ram_share_principals: ["arn:aws:organizations::123456789012:organization/o-xxxx"]
```

**After** (flat `pools`):

```yaml
pools:
  root:
    cidrs:
      primary: { cidr: "10.0.0.0/16" }
  prod:
    parent: "root"
    locale: "us-east-1"
    cidrs:
      primary: { cidr: "10.0.0.0/16" }
  workload:
    parent: "prod"
    locale: "us-east-1"
    allocation_default_netmask_length: 22
    cidrs:
      upper:  { cidr: "10.0.128.0/17" }
      second: { cidr: "10.0.64.0/18" }
    ram_share:
      principals: ["arn:aws:organizations::123456789012:organization/o-xxxx"]
```

## Re-homing existing state with `moved` blocks

Add a `moved.tf` mapping each old aws-ia address to its new module address, so an
`apply` relabels state instead of destroy/create. The old wrapper nested the
module as `module.ipam[0].module.level_zero|level_one|level_two`; the new module
partitions pools by depth as `module.ipam.aws_vpc_ipam_pool.level_0|1|2|3["<name>"]`.

```hcl
# IPAM (only when this component created it)
moved {
  from = module.ipam[0].aws_vpc_ipam.main[0]
  to   = module.ipam.aws_vpc_ipam.default[0]
}

# Top pool + its CIDR
moved {
  from = module.ipam[0].module.level_zero.aws_vpc_ipam_pool.sub
  to   = module.ipam.aws_vpc_ipam_pool.level_0["root"]
}
moved {
  from = module.ipam[0].module.level_zero.aws_vpc_ipam_pool_cidr.sub["10.0.0.0/16"]
  to   = module.ipam.aws_vpc_ipam_pool_cidr.level_0["root/primary"]
}

# Level-1 pool (aws-ia keys sub_pools by name)
moved {
  from = module.ipam[0].module.level_one["prod"].aws_vpc_ipam_pool.sub
  to   = module.ipam.aws_vpc_ipam_pool.level_1["prod"]
}

# Level-2 pool + CIDRs + RAM sharing
moved {
  from = module.ipam[0].module.level_two["prod/workload"].aws_vpc_ipam_pool.sub
  to   = module.ipam.aws_vpc_ipam_pool.level_2["workload"]
}
moved {
  from = module.ipam[0].module.level_two["prod/workload"].aws_ram_resource_share.sub[0]
  to   = module.ipam.aws_ram_resource_share.default["workload"]
}
moved {
  from = module.ipam[0].module.level_two["prod/workload"].aws_ram_resource_association.sub[0]
  to   = module.ipam.aws_ram_resource_association.default["workload"]
}
moved {
  from = module.ipam[0].module.level_two["prod/workload"].aws_ram_principal_association.sub["arn:aws:organizations::123456789012:organization/o-xxxx"]
  to   = module.ipam.aws_ram_principal_association.default["workload/arn:aws:organizations::123456789012:organization/o-xxxx"]
}
```

Notes:

- Match `cidrs`/`allocations` **byte-for-byte** with what is deployed (CIDR,
  `netmask_length`, `locale`, `description`, allocation netmask window). `locale`
  is **ForceNew** — a mismatch replaces the pool.
- The new module auto-manages a `terraform_data.pool_graph_guard` (a plan-time
  validation) — it shows as **1 to add** and is expected.
- Default IPAM scopes are **read-only** in the new module (exported as
  `private_default_scope_id` / `public_default_scope_id`). If your old setup
  managed them (e.g. an adopted-scope resource), drop them with
  `removed { ... lifecycle { destroy = false } }` — AWS rejects deleting a
  default scope.
- `aws_ram_resource_share.name` is **not** ForceNew, so the share is updated
  in-place (its ARN and attached principals are preserved) even though the new
  module names it from the null-label id.

A correct migration plans as `moved` (+ the one `pool_graph_guard` add + benign
tag updates) with **0 to destroy** and **0 forces replacement**.
