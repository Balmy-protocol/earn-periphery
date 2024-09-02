// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { TOSManager, StrategyId, IEarnStrategyRegistry } from "src/tos-manager/TOSManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TosManagerTest is PRBTest {
  event TOSUpdated(bytes32 group, bytes tos);
  event StrategyAssignedToGroup(StrategyId strategyId, bytes32 group);

  bytes32 private constant GROUP_1 = keccak256("group1");
  bytes32 private constant GROUP_2 = keccak256("group2");
  address private superAdmin = address(1);
  address private manageTosAdmin = address(2);
  IEarnStrategyRegistry private registry = IEarnStrategyRegistry(address(3));
  TOSManager private tosManager;

  function setUp() public virtual {
    tosManager = new TOSManager(registry, superAdmin, CommonUtils.arrayOf(manageTosAdmin));
  }

  function test_constants() public {
    assertEq(tosManager.MANAGE_TOS_ROLE(), keccak256("MANAGE_TOS_ROLE"));
    assertEq(address(tosManager.STRATEGY_REGISTRY()), address(registry));
  }

  function test_constructor() public {
    assertTrue(tosManager.hasRole(tosManager.MANAGE_TOS_ROLE(), manageTosAdmin));

    // Access control
    assertEq(tosManager.defaultAdminDelay(), 3 days);
    assertEq(tosManager.owner(), superAdmin);
    assertEq(tosManager.defaultAdmin(), superAdmin);
  }

  function test_getStrategyTOSHash_empty() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertEq(tosManager.getStrategyTOSHash(strategyId), bytes32(0));
  }

  function test_getStrategyTOSHash_assigned() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.prank(manageTosAdmin);
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
    vm.prank(manageTosAdmin);
    tosManager.updateTOS(GROUP_1, "tos");
    assertEq(tosManager.getStrategyTOSHash(strategyId), MessageHashUtils.toEthSignedMessageHash(bytes("tos")));
  }

  function test_updateTOS() public {
    vm.prank(manageTosAdmin);
    vm.expectEmit();
    emit TOSUpdated(GROUP_1, "new tos");
    tosManager.updateTOS(GROUP_1, "new tos");
    assertEq(tosManager.getGroupTOSHash(GROUP_1), MessageHashUtils.toEthSignedMessageHash(bytes("new tos")));
  }

  function test_updateTOS_clearTOS() public {
    // Set a TOS
    vm.prank(manageTosAdmin);
    tosManager.updateTOS(GROUP_1, "new tos");

    // Clear it
    vm.prank(manageTosAdmin);
    tosManager.updateTOS(GROUP_1, "");
    assertEq(tosManager.getGroupTOSHash(GROUP_1), bytes32(0));
  }

  function test_updateTOS_revertWhen_calledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), tosManager.MANAGE_TOS_ROLE()
      )
    );
    tosManager.updateTOS(GROUP_1, "new tos");
  }

  function test_assignStrategyToGroup_hasRole() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectEmit();
    emit StrategyAssignedToGroup(strategyId, GROUP_1);
    vm.prank(manageTosAdmin);
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
    assertEq(tosManager.getStrategyGroup(strategyId), GROUP_1);
  }

  function test_assignStrategyToGroup_strategy() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address strategy = address(4);

    vm.mockCall(
      address(registry), abi.encodeWithSelector(IEarnStrategyRegistry.getStrategy.selector), abi.encode(strategy)
    );

    vm.startPrank(strategy);
    vm.expectEmit();
    emit StrategyAssignedToGroup(strategyId, GROUP_1);
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
    assertEq(tosManager.getStrategyGroup(strategyId), GROUP_1);

    // Now try updating it again
    vm.expectEmit();
    emit StrategyAssignedToGroup(strategyId, GROUP_2);
    tosManager.assignStrategyToGroup(strategyId, GROUP_2);
    assertEq(tosManager.getStrategyGroup(strategyId), GROUP_2);
    vm.stopPrank();
  }

  function test_assignStrategyToGroup_revertWhen_calledWithoutRoleAndCallerIsNotStrategy() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectRevert(abi.encodeWithSelector(TOSManager.UnauthorizedCaller.selector));
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
  }
}
