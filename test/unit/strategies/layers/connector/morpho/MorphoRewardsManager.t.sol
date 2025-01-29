// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import {
  MorphoRewardsManager,
  MorphoConnector,
  IUniversalRewardsDistributor
} from "src/strategies/layers/connector/morpho/MorphoRewardsManager.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract MorphoRewardsManagerTest is Test {
  address private superAdmin = address(1);
  address private manageConfigurationAccount = address(2);
  MorphoConnector private connector = MorphoConnector(address(3));
  IUniversalRewardsDistributor private rewardsDistributor = IUniversalRewardsDistributor(address(4));
  MorphoRewardsManager private manager;

  function setUp() public virtual {
    manager = new MorphoRewardsManager(superAdmin, CommonUtils.arrayOf(manageConfigurationAccount));
    vm.mockCall(address(connector), abi.encodeWithSelector(MorphoConnector.configureRewards.selector), "");
    vm.mockCall(
      address(rewardsDistributor), abi.encodeWithSelector(IUniversalRewardsDistributor.claim.selector), abi.encode(0)
    );
  }

  function test_constants() public {
    assertEq(manager.MANAGE_CONFIGURATION_ROLE(), keccak256("MANAGE_CONFIGURATION_ROLE"));
  }

  function test_constructor() public {
    assertTrue(manager.hasRole(manager.MANAGE_CONFIGURATION_ROLE(), manageConfigurationAccount));

    // Access control
    assertEq(manager.defaultAdminDelay(), 3 days);
    assertEq(manager.owner(), superAdmin);
    assertEq(manager.defaultAdmin(), superAdmin);
  }

  function test_claimRewards() public {
    address rewardToken = address(5);
    uint256 claimable = 0;
    bytes32[] memory proof = new bytes32[](0);

    MorphoRewardsManager.Claim[] memory claims = new MorphoRewardsManager.Claim[](1);
    claims[0] = MorphoRewardsManager.Claim({
      rewardsDistributor: rewardsDistributor,
      rewardToken: rewardToken,
      claimable: claimable,
      proof: proof
    });
    MorphoRewardsManager.Claims[] memory allClaims = new MorphoRewardsManager.Claims[](1);
    allClaims[0] = MorphoRewardsManager.Claims({ connector: connector, claims: claims });

    vm.expectCall(
      address(rewardsDistributor),
      abi.encodeWithSelector(
        IUniversalRewardsDistributor.claim.selector, address(connector), rewardToken, claimable, proof
      )
    );
    manager.claimRewards(allClaims);
  }

  function test_configureRewards_RevertWhen_calledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.MANAGE_CONFIGURATION_ROLE()
      )
    );
    manager.configureRewards(new MorphoRewardsManager.Configuration[](0), 1 days);
  }

  function test_configureRewards() public {
    uint256 duration = 1 days;
    address[] memory tokens = CommonUtils.arrayOf(address(4));
    MorphoRewardsManager.Configuration[] memory configurations = new MorphoRewardsManager.Configuration[](1);
    configurations[0] = MorphoRewardsManager.Configuration({ connector: connector, tokens: tokens });

    vm.expectCall(
      address(connector), abi.encodeWithSelector(MorphoConnector.configureRewards.selector, tokens, duration)
    );
    vm.prank(manageConfigurationAccount);
    manager.configureRewards(configurations, duration);
  }

  function test_claimAndConfigureRewards_RevertWhen_calledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.MANAGE_CONFIGURATION_ROLE()
      )
    );
    manager.claimAndConfigureRewards(new MorphoRewardsManager.Claims[](0), 1 days);
  }

  function test_claimAndConfigureRewards() public {
    uint256 duration = 1 days;
    address rewardToken = address(5);
    uint256 claimable = 0;
    bytes32[] memory proof = new bytes32[](0);

    MorphoRewardsManager.Claim[] memory claims = new MorphoRewardsManager.Claim[](1);
    claims[0] = MorphoRewardsManager.Claim({
      rewardsDistributor: rewardsDistributor,
      rewardToken: rewardToken,
      claimable: claimable,
      proof: proof
    });
    MorphoRewardsManager.Claims[] memory allClaims = new MorphoRewardsManager.Claims[](1);
    allClaims[0] = MorphoRewardsManager.Claims({ connector: connector, claims: claims });

    vm.expectCall(
      address(rewardsDistributor),
      abi.encodeWithSelector(
        IUniversalRewardsDistributor.claim.selector, address(connector), rewardToken, claimable, proof
      )
    );
    vm.expectCall(
      address(connector),
      abi.encodeWithSelector(MorphoConnector.configureRewards.selector, CommonUtils.arrayOf(rewardToken), duration)
    );
    vm.prank(manageConfigurationAccount);
    manager.claimAndConfigureRewards(allClaims, duration);
  }
}
