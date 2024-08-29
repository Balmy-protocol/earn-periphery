// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { TOSManager, StrategyId } from "../../../src/tos-manager/TOSManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract TosManagerTest is PRBTest {
  address private superAdmin = address(1);
  address private manageTosAdmin = address(2);
  TOSManager private tosManager;

  function setUp() public virtual {
    vm.expectEmit();
    tosManager = new TOSManager(superAdmin, CommonUtils.arrayOf(manageTosAdmin));
  }

  function test_constants() public {
    assertEq(tosManager.MANAGE_TOS_ROLE(), keccak256("MANAGE_TOS_ROLE"));
  }

  function test_constructor() public {
    assertTrue(tosManager.hasRole(tosManager.MANAGE_TOS_ROLE(), manageTosAdmin));

    // Access control
    assertEq(tosManager.defaultAdminDelay(), 3 days);
    assertEq(tosManager.owner(), superAdmin);
    assertEq(tosManager.defaultAdmin(), superAdmin);
  }
}
