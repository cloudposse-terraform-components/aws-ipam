package test

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/cloudposse/test-helpers/pkg/atmos"
	helper "github.com/cloudposse/test-helpers/pkg/atmos/component-helper"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type ComponentSuite struct {
	helper.TestSuite
}

func (s *ComponentSuite) TestBasic() {
	const component = "ipam/basic"
	const stack = "default-test"
	const awsRegion = "us-east-2"

	defer s.DestroyAtmosComponent(s.T(), component, stack, nil)
	options, _ := s.DeployAtmosComponent(s.T(), component, stack, nil)
	assert.NotNil(s.T(), options)

	ipamID := atmos.Output(s.T(), options, "ipam_id")
	assert.True(s.T(), strings.HasPrefix(ipamID, "ipam-"), "Expected an IPAM ID, got %q", ipamID)

	privateScopeID := atmos.Output(s.T(), options, "private_default_scope_id")
	assert.True(s.T(), strings.HasPrefix(privateScopeID, "ipam-scope-"), "Expected a private default scope ID, got %q", privateScopeID)

	poolIDs := atmos.OutputMap(s.T(), options, "pool_ids")
	require.Len(s.T(), poolIDs, 2, "Expected one ID per pool")
	for _, poolName := range []string{"top", "regional"} {
		assert.True(s.T(), strings.HasPrefix(poolIDs[poolName], "ipam-pool-"),
			"Expected an IPAM pool ID for %q, got %q", poolName, poolIDs[poolName])
	}

	// Neither pool names a scope, so both land in the IPAM's private default scope.
	poolScopeIDs := atmos.OutputMap(s.T(), options, "pool_scope_ids")
	assert.Equal(s.T(), privateScopeID, poolScopeIDs["top"])
	assert.Equal(s.T(), privateScopeID, poolScopeIDs["regional"])

	var poolCIDRs map[string][]string
	require.NoError(s.T(), json.Unmarshal([]byte(atmos.OutputJson(s.T(), options, "pool_cidrs")), &poolCIDRs))
	assert.Equal(s.T(), []string{"10.250.0.0/16"}, poolCIDRs["top"])
	assert.Equal(s.T(), []string{"10.250.16.0/20"}, poolCIDRs["regional"])

	client := aws.NewEc2Client(s.T(), awsRegion)

	ipams, err := client.DescribeIpams(context.Background(), &ec2.DescribeIpamsInput{
		IpamIds: []string{ipamID},
	})
	require.NoError(s.T(), err)
	require.Len(s.T(), ipams.Ipams, 1)
	ipam := ipams.Ipams[0]
	assert.Equal(s.T(), types.IpamTierAdvanced, ipam.Tier)
	operatingRegions := make([]string, 0, len(ipam.OperatingRegions))
	for _, region := range ipam.OperatingRegions {
		operatingRegions = append(operatingRegions, *region.RegionName)
	}
	assert.Equal(s.T(), []string{awsRegion}, operatingRegions)

	pools, err := client.DescribeIpamPools(context.Background(), &ec2.DescribeIpamPoolsInput{
		IpamPoolIds: []string{poolIDs["top"], poolIDs["regional"]},
	})
	require.NoError(s.T(), err)
	require.Len(s.T(), pools.IpamPools, 2)
	poolsByID := make(map[string]types.IpamPool, len(pools.IpamPools))
	for _, pool := range pools.IpamPools {
		poolsByID[*pool.IpamPoolId] = pool
	}

	top := poolsByID[poolIDs["top"]]
	assert.Nil(s.T(), top.SourceIpamPoolId, "Expected the top-level pool to have no parent")
	assert.Equal(s.T(), types.AddressFamilyIpv4, top.AddressFamily)

	regional := poolsByID[poolIDs["regional"]]
	require.NotNil(s.T(), regional.SourceIpamPoolId)
	assert.Equal(s.T(), poolIDs["top"], *regional.SourceIpamPoolId, "Expected the regional pool to be carved from the top-level pool")
	require.NotNil(s.T(), regional.Locale)
	assert.Equal(s.T(), awsRegion, *regional.Locale)
	require.NotNil(s.T(), regional.AllocationDefaultNetmaskLength)
	assert.EqualValues(s.T(), 24, *regional.AllocationDefaultNetmaskLength)

	regionalCIDRs, err := client.GetIpamPoolCidrs(context.Background(), &ec2.GetIpamPoolCidrsInput{
		IpamPoolId: regional.IpamPoolId,
	})
	require.NoError(s.T(), err)
	require.Len(s.T(), regionalCIDRs.IpamPoolCidrs, 1)
	assert.Equal(s.T(), "10.250.16.0/20", *regionalCIDRs.IpamPoolCidrs[0].Cidr)
	assert.Equal(s.T(), types.IpamPoolCidrStateProvisioned, regionalCIDRs.IpamPoolCidrs[0].State)

	s.DriftTest(component, stack, nil)
}

func (s *ComponentSuite) TestEnabledFlag() {
	const component = "ipam/disabled"
	const stack = "default-test"
	s.VerifyEnabledFlag(component, stack, nil)
}

func TestRunSuite(t *testing.T) {
	suite := new(ComponentSuite)
	helper.Run(t, suite)
}
