// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { FeeManager, IFeeManager, Fees, StrategyId } from "../../../src/fee-manager/FeeManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract FeeManagerTest is PRBTest {
  event DefaultFeesChanged(Fees newFees, address recipient);
  event StrategyFeesChanged(StrategyId strategyId, Fees newFees, address recipient);

  address private superAdmin = address(1);
  address private manageFeeAdmin = address(2);
  Fees private defaultFees = Fees(400, 300, 200, 100);
  address private defaultRecipient = address(3);
  FeeManager private feeManager;

  function setUp() public virtual {
    vm.expectEmit();
    emit DefaultFeesChanged(defaultFees, defaultRecipient);
    feeManager = new FeeManager(superAdmin, CommonUtils.arrayOf(manageFeeAdmin), defaultFees, defaultRecipient);
  }

  function test_constants() public {
    assertEq(feeManager.MANAGE_FEES_ROLE(), keccak256("MANAGE_FEES_ROLE"));
    assertEq(feeManager.MAX_FEE(), 5000);
  }

  function test_constructor() public {
    assertTrue(feeManager.hasRole(feeManager.MANAGE_FEES_ROLE(), manageFeeAdmin));

    // Access control
    assertEq(feeManager.defaultAdminDelay(), 3 days);
    assertEq(feeManager.owner(), superAdmin);
    assertEq(feeManager.defaultAdmin(), superAdmin);

    (Fees memory fees, address recipient) = feeManager.defaultFees();
    assertTrue(fees.equals(defaultFees));
    assertEq(recipient, defaultRecipient);
  }

  function test_constructor_RevertWhen_FeeGreaterThanMaximum() public {
    vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeesGreaterThanMaximum.selector));
    feeManager =
      new FeeManager(superAdmin, CommonUtils.arrayOf(manageFeeAdmin), Fees(10_000, 300, 200, 100), defaultRecipient);
  }

  function test_setDefaultFees() public {
    Fees memory newDefaultFees = Fees(5, 1, 2, 3);
    address newDefaultRecipient = address(10);

    vm.prank(manageFeeAdmin);
    vm.expectEmit();
    emit DefaultFeesChanged(newDefaultFees, newDefaultRecipient);
    feeManager.setDefaultFees(newDefaultFees, newDefaultRecipient);

    (Fees memory fees, address recipient) = feeManager.defaultFees();
    assertTrue(fees.equals(newDefaultFees));
    assertEq(recipient, newDefaultRecipient);
  }

  function test_setDefaultFee_RevertWhen_CalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeManager.MANAGE_FEES_ROLE()
      )
    );
    feeManager.setDefaultFees(Fees(200, 300, 200, 100), defaultRecipient);
  }

  function test_setDefaultFee_RevertWhen_FeeGreaterThanMaximum() public {
    vm.prank(manageFeeAdmin);
    vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeesGreaterThanMaximum.selector));
    feeManager.setDefaultFees(Fees(10_000, 300, 200, 100), defaultRecipient);
  }

  function test_updateFees() public {
    vm.prank(manageFeeAdmin);
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(5, 1, 2, 3);
    address newRecipient = address(20);
    vm.expectEmit();
    emit StrategyFeesChanged(strategyId, newFees, newRecipient);
    feeManager.updateFees(strategyId, newFees, newRecipient);
    (Fees memory fees, address recipient) = feeManager.getFees(strategyId);
    assertTrue(fees.equals(newFees));
    assertEq(recipient, newRecipient);
  }

  function test_updateFees_RevertWhen_CalledWithoutRole() public {
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(5, 1, 2, 3);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), feeManager.MANAGE_FEES_ROLE()
      )
    );
    feeManager.updateFees(strategyId, newFees, defaultRecipient);
  }

  function test_updateFees_RevertWhen_FeeGreaterThanMaximum() public {
    vm.prank(manageFeeAdmin);
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(10_000, 1, 2, 3);
    vm.expectRevert(abi.encodeWithSelector(IFeeManager.FeesGreaterThanMaximum.selector));
    feeManager.updateFees(strategyId, newFees, defaultRecipient);
  }

  function test_getFees() public {
    StrategyId strategyId = StrategyId.wrap(1);

    (Fees memory fees, address recipient) = feeManager.getFees(strategyId);
    assertTrue(fees.equals(defaultFees));
    assertEq(recipient, defaultRecipient);
  }

  function test_setToDefault() public {
    StrategyId strategyId = StrategyId.wrap(1);
    Fees memory newFees = Fees(5, 1, 2, 3);
    address newRecipient = address(40);
    vm.prank(manageFeeAdmin);
    vm.expectEmit();
    emit StrategyFeesChanged(strategyId, newFees, newRecipient);
    feeManager.updateFees(strategyId, newFees, newRecipient);
    (Fees memory fees, address recipient) = feeManager.getFees(strategyId);
    assertTrue(fees.equals(newFees));
    assertEq(recipient, newRecipient);
    vm.prank(manageFeeAdmin);
    feeManager.setToDefault(strategyId);
    (fees, recipient) = feeManager.defaultFees();
    assertTrue(fees.equals(defaultFees));
    assertEq(recipient, defaultRecipient);
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
    address newRecipient = address(50);
    vm.prank(manageFeeAdmin);
    feeManager.updateFees(strategyId, newFees, newRecipient);

    assertFalse(feeManager.hasDefaultFees(strategyId));

    vm.prank(manageFeeAdmin);
    feeManager.setToDefault(strategyId);
    assertTrue(feeManager.hasDefaultFees(strategyId));
  }
}
