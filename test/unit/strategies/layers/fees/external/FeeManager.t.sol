// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import {
  FeeManager,
  IFeeManager,
  Fees,
  StrategyId,
  IEarnStrategyRegistry,
  IEarnStrategy
} from "src/strategies/layers/fees/external/FeeManager.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract FeeManagerTest is PRBTest {
  event DefaultFeesChanged(Fees newFees);
  event StrategyFeesChanged(StrategyId strategyId, Fees newFees);

  address private superAdmin = address(1);
  address private manageFeeAdmin = address(2);
  address private withdrawFeeAdmin = address(3);
  IEarnStrategyRegistry private registry = IEarnStrategyRegistry(address(4));
  IEarnStrategy private strategy = IEarnStrategy(address(5));
  Fees private defaultFees = Fees(400, 300, 200, 100);
  FeeManager private feeManager;

  function setUp() public virtual {
    vm.expectEmit();
    emit DefaultFeesChanged(defaultFees);
    feeManager = new FeeManager(
      registry, superAdmin, CommonUtils.arrayOf(manageFeeAdmin), CommonUtils.arrayOf(withdrawFeeAdmin), defaultFees
    );
  }

  function test_constants() public {
    assertEq(feeManager.MANAGE_FEES_ROLE(), keccak256("MANAGE_FEES_ROLE"));
    assertEq(feeManager.WITHDRAW_FEES_ROLE(), keccak256("WITHDRAW_FEES_ROLE"));
    assertEq(feeManager.MAX_FEE(), 5000);
  }

  function test_constructor() public {
    assertEq(address(feeManager.STRATEGY_REGISTRY()), address(registry));
    assertTrue(feeManager.hasRole(feeManager.MANAGE_FEES_ROLE(), manageFeeAdmin));
    assertTrue(feeManager.hasRole(feeManager.WITHDRAW_FEES_ROLE(), withdrawFeeAdmin));

    // Access control
    assertEq(feeManager.defaultAdminDelay(), 3 days);
    assertEq(feeManager.owner(), superAdmin);
    assertEq(feeManager.defaultAdmin(), superAdmin);

    assertTrue(feeManager.defaultFees().equals(defaultFees));
  }

  function test_constructor_RevertWhen_FeeGreaterThanMaximum() public {
    vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeesGreaterThanMaximum.selector));
    feeManager = new FeeManager(
      registry,
      superAdmin,
      CommonUtils.arrayOf(manageFeeAdmin),
      CommonUtils.arrayOf(withdrawFeeAdmin),
      Fees(10_000, 300, 200, 100)
    );
  }

  function test_strategySelfConfigure_emptyBytes() public {
    // Nothing happens
    feeManager.strategySelfConfigure("");
  }

  function test_strategySelfConfigure() public {
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(5, 1, 2, 3);

    vm.mockCall(
      address(registry), abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector), abi.encode(strategyId)
    );

    vm.expectEmit();
    emit StrategyFeesChanged(strategyId, newFees);
    vm.prank(address(strategy));
    feeManager.strategySelfConfigure(abi.encode(newFees));
    assertTrue(feeManager.getFees(strategyId).equals(newFees));
  }

  function test_strategySelfConfigure_revertWhen_callerHasNoId() public {
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector),
      abi.encode(StrategyId.wrap(0))
    );

    vm.prank(address(strategy));
    vm.expectRevert(abi.encodeWithSelector(FeeManager.UnauthorizedCaller.selector));
    feeManager.strategySelfConfigure(abi.encode(Fees(5, 1, 2, 3)));
  }

  function test_canWithdrawFees() public {
    assertTrue(feeManager.canWithdrawFees(StrategyId.wrap(1), withdrawFeeAdmin));
    assertFalse(feeManager.canWithdrawFees(StrategyId.wrap(1), manageFeeAdmin));
  }

  function test_setDefaultFees() public {
    Fees memory newDefaultFees = Fees(5, 1, 2, 3);

    vm.prank(manageFeeAdmin);
    vm.expectEmit();
    emit DefaultFeesChanged(newDefaultFees);
    feeManager.setDefaultFees(newDefaultFees);

    assertTrue(feeManager.defaultFees().equals(newDefaultFees));
  }

  function test_setDefaultFee_RevertWhen_CalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeManager.MANAGE_FEES_ROLE()
      )
    );
    feeManager.setDefaultFees(Fees(200, 300, 200, 100));
  }

  function test_setDefaultFee_RevertWhen_FeeGreaterThanMaximum() public {
    vm.prank(manageFeeAdmin);
    vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeesGreaterThanMaximum.selector));
    feeManager.setDefaultFees(Fees(10_000, 300, 200, 100));
  }

  function test_updateFees() public {
    vm.prank(manageFeeAdmin);
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(5, 1, 2, 3);
    vm.expectEmit();
    emit StrategyFeesChanged(strategyId, newFees);
    feeManager.updateFees(strategyId, newFees);
    assertTrue(feeManager.getFees(strategyId).equals(newFees));
  }

  function test_updateFees_RevertWhen_CalledWithoutRole() public {
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(5, 1, 2, 3);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeManager.MANAGE_FEES_ROLE()
      )
    );
    feeManager.updateFees(strategyId, newFees);
  }

  function test_updateFees_RevertWhen_FeeGreaterThanMaximum() public {
    vm.prank(manageFeeAdmin);
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(10_000, 1, 2, 3);
    vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeesGreaterThanMaximum.selector));
    feeManager.updateFees(strategyId, newFees);
  }

  function test_getFees() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertTrue(feeManager.getFees(strategyId).equals(defaultFees));
  }

  function test_setToDefault() public {
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(5, 1, 2, 3);
    vm.prank(manageFeeAdmin);
    vm.expectEmit();
    emit StrategyFeesChanged(strategyId, newFees);
    feeManager.updateFees(strategyId, newFees);
    assertTrue(feeManager.getFees(strategyId).equals(newFees));
    vm.prank(manageFeeAdmin);
    feeManager.setToDefault(strategyId);
    assertTrue(feeManager.getFees(strategyId).equals(defaultFees));
  }

  function test_setToDefault_RevertWhen_CalledWithoutRole() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeManager.MANAGE_FEES_ROLE()
      )
    );
    feeManager.setToDefault(strategyId);
  }

  function test_hasDefaultFees() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertTrue(feeManager.hasDefaultFees(strategyId));

    Fees memory newFees = Fees(5, 1, 2, 3);
    vm.prank(manageFeeAdmin);
    feeManager.updateFees(strategyId, newFees);

    assertFalse(feeManager.hasDefaultFees(strategyId));

    vm.prank(manageFeeAdmin);
    feeManager.setToDefault(strategyId);
    assertTrue(feeManager.hasDefaultFees(strategyId));
  }
}
