# Test

Terratest suite for the `ipam` component, run with the
[`cloudposse/test-helpers`](https://github.com/cloudposse/test-helpers) Atmos
component helper.

- `TestBasic` deploys an IPAM with a top-level pool and a regional child pool,
  checks the outputs against the EC2 API, and runs a drift test.
- `TestEnabledFlag` verifies `enabled: false` plans no resources.

AWS allows one IPAM per Region per account by default. `TestBasic` creates one
IPAM in `us-east-2`, so the `terraform` and `opentofu` matrix jobs must not run
at the same time in the same test account (repository property
`test-skip-concurrency: true`).
