// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { Test } from "forge-std/Test.sol";
import {
  ISignatureBasedWhitelistManager,
  SignatureBasedWhitelistManager,
  StrategyId,
  IEarnStrategyRegistry
} from "src/strategies/layers/creation-validation/external/SignatureBasedWhitelistManager.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";

import { VmSafe } from "forge-std/Vm.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SignatureBasedWhitelistManagerTest is Test {
  event SignerUpdated(bytes32 group, address signer);
  event StrategyAssignedToGroup(StrategyId strategyId, bytes32 group);

  bytes32 private constant GROUP_1 = keccak256("group1");
  bytes32 private constant GROUP_2 = keccak256("group2");
  address private superAdmin = address(1);
  address private noValidationAccount = address(2);
  address private nonceSpenderAccount = address(3);
  address private manageSignersAccount = address(4);
  IEarnStrategyRegistry private registry = IEarnStrategyRegistry(address(5));
  address private initialSigner = address(6);
  StrategyId private initialStrategyId = StrategyId.wrap(1000);
  SignatureBasedWhitelistManager private manager;
  VmSafe.Wallet private signer = vm.createWallet("signer");

  function setUp() public virtual {
    SignatureBasedWhitelistManager.InitialSigner[] memory initialSigners =
      new SignatureBasedWhitelistManager.InitialSigner[](1);
    initialSigners[0] = SignatureBasedWhitelistManager.InitialSigner({ signer: initialSigner, group: GROUP_1 });
    SignatureBasedWhitelistManager.InitialGroup[] memory initialGroups =
      new SignatureBasedWhitelistManager.InitialGroup[](1);
    StrategyId[] memory strategyIds = new StrategyId[](1);
    strategyIds[0] = initialStrategyId;
    initialGroups[0] = SignatureBasedWhitelistManager.InitialGroup({ strategyIds: strategyIds, group: GROUP_1 });
    manager = new SignatureBasedWhitelistManager(
      registry,
      superAdmin,
      CommonUtils.arrayOf(noValidationAccount),
      CommonUtils.arrayOf(nonceSpenderAccount),
      CommonUtils.arrayOf(manageSignersAccount),
      initialSigners,
      initialGroups
    );
  }

  function test_constants() public {
    assertEq(manager.NO_VALIDATION_ROLE(), keccak256("NO_VALIDATION_ROLE"));
    assertEq(manager.NONCE_SPENDER_ROLE(), keccak256("NONCE_SPENDER_ROLE"));
    assertEq(manager.MANAGE_SIGNERS_ROLE(), keccak256("MANAGE_SIGNERS_ROLE"));
    assertEq(
      manager.VALIDATION_TYPEHASH(),
      keccak256("Validation(uint96 strategyId,address account,uint256 deadline,uint256 nonce)")
    );
  }

  function test_constructor() public {
    assertTrue(manager.hasRole(manager.MANAGE_SIGNERS_ROLE(), manageSignersAccount));
    assertTrue(manager.hasRole(manager.NO_VALIDATION_ROLE(), noValidationAccount));
    assertTrue(manager.hasRole(manager.NONCE_SPENDER_ROLE(), nonceSpenderAccount));
    assertEq(address(manager.STRATEGY_REGISTRY()), address(registry));

    // EIP 712
    (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    ) = manager.eip712Domain();
    assertEq(fields, hex"0f");
    assertEq(name, "Balmy Earn - Signature Based Whitelist Manager");
    assertEq(version, "1");
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(manager));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);

    // Access control
    assertEq(manager.defaultAdminDelay(), 3 days);
    assertEq(manager.owner(), superAdmin);
    assertEq(manager.defaultAdmin(), superAdmin);

    // Initial config
    assertEq(manager.getGroupSigner(GROUP_1), initialSigner);
    assertEq(manager.getStrategyGroup(initialStrategyId), GROUP_1);
  }

  function test_getNonce_start() public {
    assertEq(manager.getNonce(StrategyId.wrap(1), address(50)), 0);
  }

  function test_assignStrategyToGroup() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectEmit();
    emit StrategyAssignedToGroup(strategyId, GROUP_1);
    vm.prank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    assertEq(manager.getStrategyGroup(strategyId), GROUP_1);
  }

  function test_assignStrategyToGroup_revertWhen_calledWithoutRole() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.MANAGE_SIGNERS_ROLE()
      )
    );
    manager.assignStrategyToGroup(strategyId, GROUP_1);
  }

  function test_getStrategySigner_empty() public {
    StrategyId strategyId = StrategyId.wrap(1);
    assertEq(manager.getStrategySigner(strategyId), address(0));
  }

  function test_getStrategySigner_assigned() public {
    StrategyId strategyId = StrategyId.wrap(1);
    vm.prank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    vm.prank(manageSignersAccount);
    manager.updateSigner(GROUP_1, signer.addr);
    assertEq(manager.getStrategySigner(strategyId), signer.addr);
  }

  function test_updateSigner_clear() public {
    // Set a signer
    vm.expectEmit();
    emit SignerUpdated(GROUP_1, signer.addr);
    vm.prank(manageSignersAccount);
    manager.updateSigner(GROUP_1, signer.addr);

    // Clear it
    vm.expectEmit();
    emit SignerUpdated(GROUP_1, address(0));
    vm.prank(manageSignersAccount);
    manager.updateSigner(GROUP_1, address(0));
    assertEq(manager.getGroupSigner(GROUP_1), address(0));
  }

  function test_updateSigner_revertWhen_calledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.MANAGE_SIGNERS_ROLE()
      )
    );
    manager.updateSigner(GROUP_1, address(1));
  }

  function test_strategySelfConfigure_emptyBytes() public {
    // Nothing happens
    manager.strategySelfConfigure("");
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
    manager.strategySelfConfigure(abi.encode(GROUP_1));
    assertEq(manager.getStrategyGroup(strategyId), GROUP_1);

    // Now try updating it again
    vm.expectEmit();
    emit StrategyAssignedToGroup(strategyId, GROUP_2);
    manager.strategySelfConfigure(abi.encode(GROUP_2));
    assertEq(manager.getStrategyGroup(strategyId), GROUP_2);
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
    vm.expectRevert(abi.encodeWithSelector(ISignatureBasedWhitelistManager.UnauthorizedCaller.selector));
    manager.strategySelfConfigure(abi.encode(GROUP_1));
  }

  function test_validate_noSignerAssigned() public {
    manager.validatePositionCreation(StrategyId.wrap(1), address(10), address(1000), "");
  }

  function test_validate_noValidationRole() public {
    StrategyId strategyId = StrategyId.wrap(1);

    // Set signer for strategy
    vm.startPrank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    manager.updateSigner(GROUP_1, signer.addr);
    vm.stopPrank();

    manager.validatePositionCreation(strategyId, noValidationAccount, address(1000), "");
  }

  function test_validate_revertWhen_deadlinePassed() public {
    StrategyId strategyId = StrategyId.wrap(1);

    // Set signer for strategy
    vm.startPrank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    manager.updateSigner(GROUP_1, signer.addr);
    vm.stopPrank();

    vm.expectRevert(
      abi.encodeWithSelector(
        ISignatureBasedWhitelistManager.MissedDeadline.selector, block.timestamp - 1, block.timestamp
      )
    );
    manager.validatePositionCreation(strategyId, address(10), address(1000), abi.encode("", block.timestamp - 1));
  }

  function test_validate_revertWhen_signatureIsInvalid() public {
    StrategyId strategyId = StrategyId.wrap(1);

    // Set signer for strategy
    vm.startPrank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    manager.updateSigner(GROUP_1, signer.addr);
    vm.stopPrank();

    vm.expectRevert(abi.encodeWithSelector(ISignatureBasedWhitelistManager.InvalidSignature.selector, ""));
    manager.validatePositionCreation(strategyId, address(10), address(1000), abi.encode("", block.timestamp));
  }

  function test_validate_revertWhen_nonceIsInvalid() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address accountToValidate = address(10);

    // Set signer for strategy
    vm.startPrank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    manager.updateSigner(GROUP_1, signer.addr);
    vm.stopPrank();

    bytes32 typedDataHash = _getTypedDataHash(strategyId, accountToValidate, block.timestamp, 1);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, typedDataHash);
    bytes memory signature = abi.encodePacked(r, s, v);

    vm.expectRevert(abi.encodeWithSelector(ISignatureBasedWhitelistManager.InvalidSignature.selector, signature));
    manager.validatePositionCreation(
      strategyId, accountToValidate, nonceSpenderAccount, abi.encode(signature, block.timestamp)
    );
  }

  function test_validate_notCalledByStrategy() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address accountToValidate = address(10);
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector),
      abi.encode(StrategyId.wrap(0))
    );

    // Set signer for strategy
    vm.startPrank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    manager.updateSigner(GROUP_1, signer.addr);
    vm.stopPrank();

    bytes32 typedDataHash = _getTypedDataHash(strategyId, accountToValidate, block.timestamp, 0);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, typedDataHash);
    bytes memory signature = abi.encodePacked(r, s, v);

    manager.validatePositionCreation(
      strategyId, accountToValidate, nonceSpenderAccount, abi.encode(signature, block.timestamp)
    );

    // Even though the request was made by the nonce spender, the caller wasn't the strategy
    assertEq(manager.getNonce(strategyId, accountToValidate), 0);
  }

  function test_validate_callerNotNonceSpender() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address accountToValidate = address(10);
    vm.mockCall(
      address(registry), abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector), abi.encode(strategyId)
    );

    // Set signer for strategy
    vm.startPrank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    manager.updateSigner(GROUP_1, signer.addr);
    vm.stopPrank();

    bytes32 typedDataHash = _getTypedDataHash(strategyId, accountToValidate, block.timestamp, 0);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, typedDataHash);
    bytes memory signature = abi.encodePacked(r, s, v);

    manager.validatePositionCreation(strategyId, accountToValidate, address(50), abi.encode(signature, block.timestamp));

    // Even though caller was the strategy, request wasn't made by nonce spender
    assertEq(manager.getNonce(strategyId, accountToValidate), 0);
  }

  function test_validate() public {
    StrategyId strategyId = StrategyId.wrap(1);
    address accountToValidate = address(10);
    vm.mockCall(
      address(registry), abi.encodeWithSelector(IEarnStrategyRegistry.assignedId.selector), abi.encode(strategyId)
    );

    // Set signer for strategy
    vm.startPrank(manageSignersAccount);
    manager.assignStrategyToGroup(strategyId, GROUP_1);
    manager.updateSigner(GROUP_1, signer.addr);
    vm.stopPrank();

    bytes32 typedDataHash = _getTypedDataHash(strategyId, accountToValidate, block.timestamp, 0);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, typedDataHash);
    bytes memory signature = abi.encodePacked(r, s, v);

    manager.validatePositionCreation(
      strategyId, accountToValidate, nonceSpenderAccount, abi.encode(signature, block.timestamp)
    );

    // Nonce was incremented
    assertEq(manager.getNonce(strategyId, accountToValidate), 1);
  }

  function _getStructHash(
    StrategyId strategyId,
    address account,
    uint256 deadline,
    uint256 nonce
  )
    private
    view
    returns (bytes32)
  {
    return keccak256(abi.encode(manager.VALIDATION_TYPEHASH(), strategyId, account, deadline, nonce));
  }

  function _getTypedDataHash(
    StrategyId strategyId,
    address account,
    uint256 deadline,
    uint256 nonce
  )
    private
    view
    returns (bytes32)
  {
    return keccak256(
      abi.encodePacked("\x19\x01", manager.DOMAIN_SEPARATOR(), _getStructHash(strategyId, account, deadline, nonce))
    );
  }
}
