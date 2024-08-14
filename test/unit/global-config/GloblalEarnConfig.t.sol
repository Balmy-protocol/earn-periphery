// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { GlobalEarnConfig, IGlobalEarnConfig } from "src/global-config/GlobalEarnConfig.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract GlobalEarnConfigTest is PRBTest {
  event DefaultFeeChanged(uint16 feeBps);

  address private superAdmin = address(1);
  address private manageFeeAdmin = address(2);
  uint16 private defaultFee = 300;
  GlobalEarnConfig private globalConfig;

  function setUp() public virtual {
    vm.expectEmit();
    emit DefaultFeeChanged(defaultFee);
    globalConfig = new GlobalEarnConfig(superAdmin, CommonUtils.arrayOf(manageFeeAdmin), defaultFee);
  }

  function test_constants() public {
    assertEq(globalConfig.MANAGE_FEES_ROLE(), keccak256("MANAGE_FEES_ROLE"));
  }

  function test_constructor() public {
    assertTrue(globalConfig.hasRole(globalConfig.MANAGE_FEES_ROLE(), manageFeeAdmin));

    // Access control
    assertEq(globalConfig.defaultAdminDelay(), 3 days);
    assertEq(globalConfig.owner(), superAdmin);
    assertEq(globalConfig.defaultAdmin(), superAdmin);

    assertEq(globalConfig.defaultFee(), defaultFee);
  }

  function test_constructor_RevertWhen_FeeGreaterThanMaximum() public {
    vm.expectRevert(abi.encodeWithSelector(IGlobalEarnConfig.FeeGreaterThanMaximum.selector));
    globalConfig = new GlobalEarnConfig(superAdmin, CommonUtils.arrayOf(manageFeeAdmin), 10_000);
  }

  function test_setDefaultFee() public {
    uint16 newDefaultFee = 5;

    vm.prank(manageFeeAdmin);
    vm.expectEmit();
    emit DefaultFeeChanged(newDefaultFee);
    globalConfig.setDefaultFee(newDefaultFee);

    assertEq(globalConfig.defaultFee(), newDefaultFee);
  }

  function test_setDefaultFee_RevertWhen_CalledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), globalConfig.MANAGE_FEES_ROLE()
      )
    );
    globalConfig.setDefaultFee(200);
  }

  function test_setDefaultFee_RevertWhen_FeeGreaterThanMaximum() public {
    vm.prank(manageFeeAdmin);
    vm.expectRevert(abi.encodeWithSelector(IGlobalEarnConfig.FeeGreaterThanMaximum.selector));
    globalConfig.setDefaultFee(10_000);
  }
}
