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
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract GuardianManagerTest is PRBTest {
  event RescueStarted(StrategyId strategyId);
  event RescueCancelled(StrategyId strategyId);
  event RescueConfirmed(StrategyId strategyId);
  event GuardiansAssigned(StrategyId strategyId, address[] accounts);
  event GuardiansRemoved(StrategyId strategyId, address[] accounts);
  event JudgesAssigned(StrategyId strategyId, address[] accounts);
  event JudgesRemoved(StrategyId strategyId, address[] accounts);

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

  function test_canStartRescue_strategyGuardian() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address guardian = address(30);
    vm.prank(manageGuardiansAdmin);
    manager.assignGuardians(strategyId, CommonUtils.arrayOf(guardian));
    assertTrue(manager.canStartRescue(strategyId, guardian));
  }

  function test_canStartRescue_globalGuardian() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertTrue(manager.canStartRescue(strategyId, globalGuardian));
  }

  function test_canStartRescue_notGuardian() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertFalse(manager.canStartRescue(strategyId, address(30)));
  }

  function test_canCancelRescue_strategyGuardian() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address guardian = address(30);
    vm.prank(manageGuardiansAdmin);
    manager.assignGuardians(strategyId, CommonUtils.arrayOf(guardian));
    assertTrue(manager.canCancelRescue(strategyId, guardian));
  }

  function test_canCancelRescue_globalGuardian() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertTrue(manager.canCancelRescue(strategyId, globalGuardian));
  }

  function test_canCancelRescue_notGuardian() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertFalse(manager.canCancelRescue(strategyId, address(30)));
  }

  function test_canConfirmRescue_strategyJudge() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address judge = address(30);
    vm.prank(manageJudgesAdmin);
    manager.assignJudges(strategyId, CommonUtils.arrayOf(judge));
    assertTrue(manager.canConfirmRescue(strategyId, judge));
  }

  function test_canConfirmRescue_globalJudge() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertTrue(manager.canConfirmRescue(strategyId, globalJudge));
  }

  function test_canConfirmRescue_notJusge() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertFalse(manager.canConfirmRescue(strategyId, address(30)));
  }

  function test_strategySelfConfigure_emptyBytes() public {
    // Nothing happens
    manager.strategySelfConfigure("");
  }

  function test_strategySelfConfigure() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address strategy = address(14);
    address newGuardian = address(15);
    address newJudge = address(16);

    vm.mockCall(
      address(registry), abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector), abi.encode(strategyId)
    );

    vm.prank(strategy);
    vm.expectEmit();
    emit GuardiansAssigned(strategyId, CommonUtils.arrayOf(newGuardian));
    emit JudgesAssigned(strategyId, CommonUtils.arrayOf(newJudge));
    manager.strategySelfConfigure(abi.encode(CommonUtils.arrayOf(newGuardian), CommonUtils.arrayOf(newJudge)));
    assertTrue(manager.isGuardian(strategyId, newGuardian));
    assertTrue(manager.isJudge(strategyId, newJudge));
  }

  function test_strategySelfConfigure_revertWhen_callerHasNoId() public {
    address strategy = address(4);

    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector),
      abi.encode(StrategyId.wrap(0))
    );

    vm.prank(strategy);
    vm.expectRevert(abi.encodeWithSelector(GuardianManager.UnauthorizedCaller.selector));
    manager.strategySelfConfigure(abi.encode(CommonUtils.arrayOf(address(1)), CommonUtils.arrayOf(address(2))));
  }

  function test_rescueStarted() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectEmit();
    emit RescueStarted(strategyId);
    manager.rescueStarted(strategyId);
  }

  function test_rescueCancelled() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectEmit();
    emit RescueCancelled(strategyId);
    manager.rescueCancelled(strategyId);
  }

  function test_rescueConfirmed() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectEmit();
    emit RescueConfirmed(strategyId);
    manager.rescueConfirmed(strategyId);
  }

  function test_assignGuardians() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address newGuardian = address(15);
    vm.expectEmit();
    emit GuardiansAssigned(strategyId, CommonUtils.arrayOf(newGuardian));
    vm.prank(manageGuardiansAdmin);
    manager.assignGuardians(strategyId, CommonUtils.arrayOf(newGuardian));
    assertTrue(manager.isGuardian(strategyId, newGuardian));
  }

  function test_assignGuardians_revertWhen_CalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.MANAGE_GUARDIANS_ROLE()
      )
    );
    manager.assignGuardians(StrategyId.wrap(1), CommonUtils.arrayOf(address(1)));
  }

  function test_removeGuardians() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address newGuardian = address(15);
    vm.prank(manageGuardiansAdmin);
    manager.assignGuardians(strategyId, CommonUtils.arrayOf(newGuardian));
    vm.expectEmit();
    emit GuardiansRemoved(strategyId, CommonUtils.arrayOf(newGuardian));
    vm.prank(manageGuardiansAdmin);
    manager.removeGuardians(strategyId, CommonUtils.arrayOf(newGuardian));
    assertFalse(manager.isGuardian(strategyId, newGuardian));
  }

  function test_removeGuardians_revertWhen_CalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.MANAGE_GUARDIANS_ROLE()
      )
    );
    manager.removeGuardians(StrategyId.wrap(1), CommonUtils.arrayOf(address(1)));
  }

  function test_assignJudges() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address newJudge = address(15);
    vm.expectEmit();
    emit JudgesAssigned(strategyId, CommonUtils.arrayOf(newJudge));
    vm.prank(manageJudgesAdmin);
    manager.assignJudges(strategyId, CommonUtils.arrayOf(newJudge));
    assertTrue(manager.isJudge(strategyId, newJudge));
  }

  function test_assignJudges_revertWhen_CalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.MANAGE_JUDGES_ROLE()
      )
    );
    manager.assignJudges(StrategyId.wrap(1), CommonUtils.arrayOf(address(1)));
  }

  function test_removeJudges() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address newJudge = address(15);
    vm.prank(manageJudgesAdmin);
    manager.assignJudges(strategyId, CommonUtils.arrayOf(newJudge));
    vm.expectEmit();
    emit JudgesRemoved(strategyId, CommonUtils.arrayOf(newJudge));
    vm.prank(manageJudgesAdmin);
    manager.removeJudges(strategyId, CommonUtils.arrayOf(newJudge));
    assertFalse(manager.isJudge(strategyId, newJudge));
  }

  function test_removeJudges_revertWhen_CalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.MANAGE_JUDGES_ROLE()
      )
    );
    manager.removeJudges(StrategyId.wrap(1), CommonUtils.arrayOf(address(1)));
  }
}
