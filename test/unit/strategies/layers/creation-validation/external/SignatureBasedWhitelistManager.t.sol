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
  event TOSUpdated(bytes32 group, bytes tos);
  event StrategyAssignedToGroup(StrategyId strategyId, bytes32 group);

  bytes32 private constant GROUP_1 = keccak256("group1");
  bytes32 private constant GROUP_2 = keccak256("group2");
  address private superAdmin = address(1);
  address private noValidationAccount = address(2);
  address private nonceSpenderAccount = address(3);
  address private manageSignersAccount = address(4);
  IEarnStrategyRegistry private registry = IEarnStrategyRegistry(address(5));
  SignatureBasedWhitelistManager private manager;
  VmSafe.Wallet private alice = vm.createWallet("alice");

  function setUp() public virtual {
    manager = new SignatureBasedWhitelistManager(
      registry,
      superAdmin,
      CommonUtils.arrayOf(noValidationAccount),
      CommonUtils.arrayOf(nonceSpenderAccount),
      CommonUtils.arrayOf(manageSignersAccount)
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
  }
}
