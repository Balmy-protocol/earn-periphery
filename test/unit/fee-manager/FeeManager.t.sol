// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { FeeManager, IFeeManager, Fees, StrategyId } from "../../../src/fee-manager/FeeManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract FeeManagerTest is PRBTest {
  event DefaultFeesChanged(Fees newFees);
  event StrategyFeesChanged(StrategyId strategyId, Fees newFees);

  address private superAdmin = address(1);
  address private manageFeeAdmin = address(2);
  Fees private defaultFees = Fees(400, 300, 200, 100);
  FeeManager private feeManager;

  function setUp() public virtual {
    vm.expectEmit();
    emit DefaultFeesChanged(defaultFees);
    feeManager = new FeeManager(superAdmin, CommonUtils.arrayOf(manageFeeAdmin), defaultFees);
  }

  function test_constants() public {
    assertEq(feeManager.MANAGE_FEES_ROLE(), keccak256("MANAGE_FEES_ROLE"));
  }

  function test_constructor() public {
    assertTrue(feeManager.hasRole(feeManager.MANAGE_FEES_ROLE(), manageFeeAdmin));

    // Access control
    assertEq(feeManager.defaultAdminDelay(), 3 days);
    assertEq(feeManager.owner(), superAdmin);
    assertEq(feeManager.defaultAdmin(), superAdmin);

    assert(feeManager.defaultFees().equals(defaultFees));
  }

  function test_constructor_RevertWhen_FeeGreaterThanMaximum() public {
    vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeesGreaterThanMaximum.selector));
    feeManager = new FeeManager(superAdmin, CommonUtils.arrayOf(manageFeeAdmin), Fees(10_000, 300, 200, 100));
  }

  function test_setDefaultFees() public {
    Fees memory newDefaultFees = Fees(5, 1, 2, 3);

    vm.prank(manageFeeAdmin);
    vm.expectEmit();
    emit DefaultFeesChanged(newDefaultFees);
    feeManager.setDefaultFees(newDefaultFees);

    assert(feeManager.defaultFees().equals(newDefaultFees));
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
    assert(feeManager.getFees(strategyId).equals(newFees));
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
}
