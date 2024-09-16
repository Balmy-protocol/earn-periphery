// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { Test } from "forge-std/Test.sol";
import { ITOSManager, TOSManager, StrategyId, IEarnStrategyRegistry } from "src/tos-manager/TOSManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";

import { VmSafe } from "forge-std/Vm.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TosManagerTest is Test {
  event TOSUpdated(bytes32 group, bytes tos);
  event StrategyAssignedToGroup(StrategyId strategyId, bytes32 group);

  bytes32 private constant GROUP_1 = keccak256("group1");
  bytes32 private constant GROUP_2 = keccak256("group2");
  address private superAdmin = address(1);
  address private manageTosAdmin = address(2);
  IEarnStrategyRegistry private registry = IEarnStrategyRegistry(address(3));
  TOSManager private tosManager;
  VmSafe.Wallet private alice = vm.createWallet("alice");

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

  function test_validate_tosIsSet_signature() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.startPrank(manageTosAdmin);
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
    tosManager.updateTOS(GROUP_1, "tos");
    vm.stopPrank();

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, tosManager.getStrategyTOSHash(strategyId));
    bytes memory signature = abi.encodePacked(r, s, v);
    tosManager.validatePositionCreation(strategyId, alice.addr, signature);
  }

  function test_validate_tosIsSet_ERC1271() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.startPrank(manageTosAdmin);
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
    tosManager.updateTOS(GROUP_1, "tos");
    vm.stopPrank();

    bytes memory signature = "my signature";
    MyContract caller = new MyContract(tosManager.getStrategyTOSHash(strategyId), signature);
    tosManager.validatePositionCreation(strategyId, address(caller), signature);
  }

  function test_validate_tosIsNotSet() public view {
    // Since TOS is empty, signature can be anything
    StrategyId strategyId = StrategyId.wrap(1);
    tosManager.validatePositionCreation(strategyId, address(0), "");
  }

  function test_validate_revertWhen_signatureIsInvalid() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.startPrank(manageTosAdmin);
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
    tosManager.updateTOS(GROUP_1, "tos");
    vm.stopPrank();

    vm.expectRevert(abi.encodeWithSelector(ITOSManager.InvalidTOSSignature.selector));
    tosManager.validatePositionCreation(strategyId, alice.addr, "");
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

  function test_assignStrategyToGroup() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectEmit();
    emit StrategyAssignedToGroup(strategyId, GROUP_1);
    vm.prank(manageTosAdmin);
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
    assertEq(tosManager.getStrategyGroup(strategyId), GROUP_1);
  }

  function test_assignStrategyToGroup_revertWhen_calledWithoutRole() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), tosManager.MANAGE_TOS_ROLE()
      )
    );
    tosManager.assignStrategyToGroup(strategyId, GROUP_1);
  }

  function test_strategySelfConfigure_emptyBytes() public {
    // Nothing happens
    tosManager.strategySelfConfigure("");
  }

  function test_strategySelfConfigure() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address strategy = address(4);

    vm.mockCall(
      address(registry), abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector), abi.encode(strategyId)
    );

    vm.startPrank(strategy);
    vm.expectEmit();
    emit StrategyAssignedToGroup(strategyId, GROUP_1);
    tosManager.strategySelfConfigure(abi.encode(GROUP_1));
    assertEq(tosManager.getStrategyGroup(strategyId), GROUP_1);

    // Now try updating it again
    vm.expectEmit();
    emit StrategyAssignedToGroup(strategyId, GROUP_2);
    tosManager.strategySelfConfigure(abi.encode(GROUP_2));
    assertEq(tosManager.getStrategyGroup(strategyId), GROUP_2);
    vm.stopPrank();
  }

  function test_strategySelfConfigure_revertWhen_callerHasNoId() public {
    address strategy = address(4);

    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector),
      abi.encode(StrategyId.wrap(0))
    );

    vm.prank(strategy);
    vm.expectRevert(abi.encodeWithSelector(TOSManager.UnauthorizedCaller.selector));
    tosManager.strategySelfConfigure(abi.encode(GROUP_1));
  }
}

contract MyContract is IERC1271 {
  bytes32 private _expectedHash;
  bytes private _expectedSignature;

  constructor(bytes32 expectedHash, bytes memory expectedSignature) {
    _expectedHash = expectedHash;
    _expectedSignature = expectedSignature;
  }

  function isValidSignature(bytes32 hash, bytes memory signature) external view override returns (bytes4 magicValue) {
    return
      hash == _expectedHash && keccak256(signature) == keccak256(_expectedSignature) ? bytes4(0x1626ba7e) : bytes4(0x0);
  }
}
