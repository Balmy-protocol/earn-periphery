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
  struct InitialSigner {
    address signer;
    bytes32 group;
  }

  struct InitialGroup {
    StrategyId[] strategyIds;
    bytes32 group;
  }

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
  mapping(bytes32 key => uint256 nonce) internal _nonces;

  constructor(
    IEarnStrategyRegistry registry,
    address superAdmin,
    address[] memory initialNoValidation,
    address[] memory initialNonceSpenders,
    address[] memory initialManagerSigners,
    InitialSigner[] memory initialSigners,
    InitialGroup[] memory initialGroups
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
    EIP712("Balmy Earn - Signature Based Whitelist Manager", "1")
  {
    STRATEGY_REGISTRY = registry;
    _grantRoles(NO_VALIDATION_ROLE, initialNoValidation);
    _grantRoles(NONCE_SPENDER_ROLE, initialNonceSpenders);
    _grantRoles(MANAGE_SIGNERS_ROLE, initialManagerSigners);
    for (uint256 i; i < initialSigners.length; ++i) {
      _assignSigner(initialSigners[i].group, initialSigners[i].signer);
    }
    for (uint256 i; i < initialGroups.length; ++i) {
      StrategyId[] memory strategyIds = initialGroups[i].strategyIds;
      for (uint256 j; j < strategyIds.length; ++j) {
        _assignGroup(strategyIds[j], initialGroups[i].group);
      }
    }
  }

  /// @inheritdoc ISignatureBasedWhitelistManager
  // slither-disable-next-line naming-convention
  function DOMAIN_SEPARATOR() public view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @inheritdoc ISignatureBasedWhitelistManager
  function getNonce(StrategyId strategyId, address account) public view returns (uint256) {
    return _nonces[_key(strategyId, account)];
  }

  /// @inheritdoc ISignatureBasedWhitelistManager
  function getStrategySigner(StrategyId strategyId) public view returns (address) {
    bytes32 group = getStrategyGroup[strategyId];
    if (group == bytes32(0)) return address(0);
    return getGroupSigner[group];
  }

  /// @inheritdoc ISignatureBasedWhitelistManager
  function updateSigner(bytes32 group, address signer) external onlyRole(MANAGE_SIGNERS_ROLE) {
    _assignSigner(group, signer);
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
  {
    address signer = getStrategySigner(strategyId);
    if (signer == address(0) || hasRole(NO_VALIDATION_ROLE, toValidate)) {
      // If there is no signer set for this strategy or the address to validate is allowlisted, then we can skip the
      // validation
      return;
    }

    // Decode data
    (bytes memory signature, uint256 deadline) = abi.decode(data, (bytes, uint256));
    // slither-disable-next-line timestamp
    if (block.timestamp > deadline) {
      // Revert if deadline was missed
      revert MissedDeadline(deadline, block.timestamp);
    }

    // Validate signature
    bytes32 key = _key(strategyId, toValidate);
    uint256 nonce = _nonces[key];
    bytes32 hashToVerify =
      _hashTypedDataV4(keccak256(abi.encode(VALIDATION_TYPEHASH, strategyId, toValidate, deadline, nonce)));
    if (!SignatureChecker.isValidSignatureNow(signer, hashToVerify, signature)) {
      revert InvalidSignature(signature);
    }

    // If this function was called by the strategy, and the validation was requested by someone that can spend nonces,
    // then we'll do so
    if (
      STRATEGY_REGISTRY.assignedId(IEarnStrategy(msg.sender)) == strategyId
        && hasRole(NONCE_SPENDER_ROLE, validationRequestedBy)
    ) {
      _nonces[key] = nonce + 1;
    }
  }

  /// @inheritdoc ICreationValidationManagerCore
  function strategySelfConfigure(bytes calldata data) external {
    if (data.length == 0) {
      return;
    }

    // Find the caller's strategy id
    StrategyId strategyId = STRATEGY_REGISTRY.assignedId(IEarnStrategy(msg.sender));
    if (strategyId == StrategyIdConstants.NO_STRATEGY) {
      revert UnauthorizedCaller();
    }

    // Decode the group from the data and assign it to the strategy
    bytes32 group = abi.decode(data, (bytes32));
    _assignGroup(strategyId, group);
  }

  function _grantRoles(bytes32 role, address[] memory accounts) private {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }

  function _assignSigner(bytes32 group, address signer) internal {
    getGroupSigner[group] = signer;
    emit SignerUpdated(group, signer);
  }

  function _assignGroup(StrategyId strategyId, bytes32 group) internal {
    getStrategyGroup[strategyId] = group;
    emit StrategyAssignedToGroup(strategyId, group);
  }

  function _key(StrategyId strategyId, address account) private pure returns (bytes32) {
    return keccak256(abi.encode(strategyId, account));
  }
}
