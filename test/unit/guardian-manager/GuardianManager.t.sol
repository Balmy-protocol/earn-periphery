// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import {
  GuardianManager,
  IGuardianManager,
  StrategyId,
  IEarnStrategyRegistry
} from "../../../src/guardian-manager/GuardianManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";

contract GuardianManagerTest is PRBTest {
  address private superAdmin = address(1);
  address private globalGuardian = address(2);
  address private globalJudge = address(3);
  address private manageGuardiansAdmin = address(4);
  address private manageJudgesAdmin = address(5);
  IEarnStrategyRegistry private registry = IEarnStrategyRegistry(address(6));
  GuardianManager private manager;

  function setUp() public virtual {
    manager = new GuardianManager(
      registry,
      superAdmin,
      CommonUtils.arrayOf(globalGuardian),
      CommonUtils.arrayOf(globalJudge),
      CommonUtils.arrayOf(manageGuardiansAdmin),
      CommonUtils.arrayOf(manageJudgesAdmin)
    );
  }

  function test_constants() public {
    assertEq(manager.GLOBAL_GUARDIAN_ROLE(), keccak256("GLOBAL_GUARDIAN_ROLE"));
    assertEq(manager.GLOBAL_JUDGE_ROLE(), keccak256("GLOBAL_JUDGE_ROLE"));
    assertEq(manager.MANAGE_GUARDIANS_ROLE(), keccak256("MANAGE_GUARDIANS_ROLE"));
    assertEq(manager.MANAGE_JUDGES_ROLE(), keccak256("MANAGE_JUDGES_ROLE"));
  }

  function test_constructor() public {
    assertEq(address(manager.STRATEGY_REGISTRY()), address(registry));

    assertTrue(manager.hasRole(manager.GLOBAL_GUARDIAN_ROLE(), globalGuardian));
    assertTrue(manager.hasRole(manager.GLOBAL_JUDGE_ROLE(), globalJudge));
    assertTrue(manager.hasRole(manager.MANAGE_GUARDIANS_ROLE(), manageGuardiansAdmin));
    assertTrue(manager.hasRole(manager.MANAGE_JUDGES_ROLE(), manageJudgesAdmin));

    // Access control
    assertEq(manager.defaultAdminDelay(), 3 days);
    assertEq(manager.owner(), superAdmin);
    assertEq(manager.defaultAdmin(), superAdmin);
  }

  function test_rescueStarted() public {
    // Make sure it can be called without reverting
    manager.rescueStarted(StrategyId.wrap(1));
  }

  function test_rescueCancelled() public {
    // Make sure it can be called without reverting
    manager.rescueCancelled(StrategyId.wrap(1));
  }

  function test_rescueConfirmed() public {
    // Make sure it can be called without reverting
    manager.rescueConfirmed(StrategyId.wrap(1));
  }
}
