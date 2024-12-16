// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import {
  ISignatureBasedWhitelistManager,
  IEarnStrategyRegistry,
  StrategyId,
  ICreationValidationManagerCore
} from "src/interfaces/ISignatureBasedWhitelistManager.sol";

contract SignatureBasedWhitelistManager is ISignatureBasedWhitelistManager, EIP712, AccessControlDefaultAdminRules {
  /// @inheritdoc ISignatureBasedWhitelistManager
  bytes32 public constant NO_VALIDATION_ROLE = keccak256("NO_VALIDATION_ROLE");
  /// @inheritdoc ISignatureBasedWhitelistManager
  bytes32 public constant NONCE_SPENDER_ROLE = keccak256("NONCE_SPENDER_ROLE");
  /// @inheritdoc ISignatureBasedWhitelistManager
  bytes32 public constant MANAGE_SIGNERS_ROLE = keccak256("MANAGE_SIGNERS_ROLE");
  /// @inheritdoc ISignatureBasedWhitelistManager
  bytes32 public constant VALIDATION_TYPEHASH =
    keccak256("Validation(uint96 strategyId,address account,uint256 deadline,uint256 nonce)");

  /// @inheritdoc ISignatureBasedWhitelistManager
  // slither-disable-next-line naming-convention
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;
  /// @inheritdoc ISignatureBasedWhitelistManager
  mapping(StrategyId strategyId => bytes32 group) public getStrategyGroup;
  /// @inheritdoc ISignatureBasedWhitelistManager
  mapping(bytes32 group => address signer) public getGroupSigner;

  constructor(
    IEarnStrategyRegistry registry,
    address superAdmin,
    address[] memory initialNoValidation,
    address[] memory initialNonceSpenders,
    address[] memory initialManagerSigners
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
    EIP712("Balmy Earn - Signature Based Whitelist Manager", "1")
  {
    STRATEGY_REGISTRY = registry;
    _grantRoles(NO_VALIDATION_ROLE, initialNoValidation);
    _grantRoles(NONCE_SPENDER_ROLE, initialNonceSpenders);
    _grantRoles(MANAGE_SIGNERS_ROLE, initialManagerSigners);
  }

  /// @inheritdoc ISignatureBasedWhitelistManager
  function getNonce(StrategyId strategyId, address account) public view returns (uint256) { }

  /// @inheritdoc ISignatureBasedWhitelistManager
  function getStrategySigner(StrategyId strategyId) public view returns (address) {
    bytes32 group = getStrategyGroup[strategyId];
    if (group == bytes32(0)) return address(0);
    return getGroupSigner[group];
  }

  /// @inheritdoc ISignatureBasedWhitelistManager
  function updateSigner(bytes32 group, address signer) external onlyRole(MANAGE_SIGNERS_ROLE) {
    getGroupSigner[group] = signer;
    emit SignerUpdated(group, signer);
  }

  /// @inheritdoc ISignatureBasedWhitelistManager
  function assignStrategyToGroup(StrategyId strategyId, bytes32 group) external onlyRole(MANAGE_SIGNERS_ROLE) {
    _assignGroup(strategyId, group);
  }

  /// @inheritdoc ICreationValidationManagerCore
  function validatePositionCreation(
    StrategyId strategyId,
    address toValidate,
    address validationRequestedBy,
    bytes calldata data
  )
    external
  { }

  /// @inheritdoc ICreationValidationManagerCore
  function strategySelfConfigure(bytes calldata data) external { }

  function _grantRoles(bytes32 role, address[] memory accounts) private {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }

  function _assignGroup(StrategyId strategyId, bytes32 group) internal {
    getStrategyGroup[strategyId] = group;
    emit StrategyAssignedToGroup(strategyId, group);
  }
}
