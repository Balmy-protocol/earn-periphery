// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { TOSManager, StrategyId } from "../../../src/tos-manager/TOSManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TosManagerTest is PRBTest {
  event TOSUpdated(bytes32 group, bytes tos);
  event StrategyAssignedToGroup(StrategyId strategyId, bytes32 group);

  bytes32 private constant group1 = keccak256("group1");
  address private superAdmin = address(1);
  address private manageTosAdmin = address(2);
  TOSManager private tosManager;

  function setUp() public virtual {
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

  function test_updateTOS() public {
    vm.prank(manageTosAdmin);
    vm.expectEmit();
    emit TOSUpdated(group1, "new tos");
    tosManager.updateTOS(group1, "new tos");
    assertEq(tosManager.getGroupTOSHash(group1), MessageHashUtils.toEthSignedMessageHash(bytes("new tos")));
  }

  function test_updateTOS_revertWhen_calledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), tosManager.MANAGE_TOS_ROLE()
      )
    );
    tosManager.updateTOS(group1, "new tos");
  }
}
