// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { ITOSManager, ICreationValidationManagerCore, IEarnStrategyRegistry } from "src/interfaces/ITOSManager.sol";

contract TOSManager is ITOSManager, AccessControlDefaultAdminRules {
  using MessageHashUtils for bytes;

  struct InitialToS {
    string tos;
    bytes32 group;
  }

  struct InitialGroup {
    StrategyId[] strategyIds;
    bytes32 group;
  }

  error UnauthorizedCaller();

  /// @inheritdoc ITOSManager
  bytes32 public constant MANAGE_TOS_ROLE = keccak256("MANAGE_TOS_ROLE");
  /// @inheritdoc ITOSManager
  // slither-disable-next-line naming-convention
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;
  /// @inheritdoc ITOSManager
  mapping(StrategyId strategyId => bytes32 group) public getStrategyGroup;
  /// @inheritdoc ITOSManager
  mapping(bytes32 group => bytes32 tosHash) public getGroupTOSHash;

  constructor(
    IEarnStrategyRegistry registry,
    address superAdmin,
    address[] memory initialManageTOSAdmins,
    InitialToS[] memory initialToS,
    InitialGroup[] memory initialGroups
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    STRATEGY_REGISTRY = registry;
    for (uint256 i; i < initialManageTOSAdmins.length; ++i) {
      _grantRole(MANAGE_TOS_ROLE, initialManageTOSAdmins[i]);
    }
    for (uint256 i; i < initialToS.length; ++i) {
      _assignToS(initialToS[i].group, initialToS[i].tos);
    }
    for (uint256 i; i < initialGroups.length; ++i) {
      StrategyId[] memory strategyIds = initialGroups[i].strategyIds;
      for (uint256 j; j < strategyIds.length; ++j) {
        _assignGroup(strategyIds[j], initialGroups[i].group);
      }
    }
  }

  /// @inheritdoc ITOSManager
  function getStrategyTOSHash(StrategyId strategyId) public view returns (bytes32) {
    bytes32 group = getStrategyGroup[strategyId];
    if (group == bytes32(0)) return bytes32(0);
    return getGroupTOSHash[group];
  }

  /// @inheritdoc ICreationValidationManagerCore
  function validatePositionCreation(
    StrategyId strategyId,
    address toValidate,
    address,
    bytes calldata signature
  )
    external
    view
  {
    bytes32 tosHash = getStrategyTOSHash(strategyId);
    if (tosHash != bytes32(0) && !SignatureChecker.isValidSignatureNow(toValidate, tosHash, signature)) {
      revert InvalidTOSSignature();
    }
  }

  /// @inheritdoc ITOSManager
  function updateTOS(bytes32 group, string calldata tos) external onlyRole(MANAGE_TOS_ROLE) {
    _assignToS(group, tos);
  }

  /// @inheritdoc ITOSManager
  function assignStrategyToGroup(StrategyId strategyId, bytes32 group) external onlyRole(MANAGE_TOS_ROLE) {
    _assignGroup(strategyId, group);
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

  function _assignGroup(StrategyId strategyId, bytes32 group) internal {
    getStrategyGroup[strategyId] = group;
    emit StrategyAssignedToGroup(strategyId, group);
  }

  function _assignToS(bytes32 group, string memory tos) internal {
    bytes memory tosBytes = bytes(tos);
    bytes32 tosHash = tosBytes.length == 0 ? bytes32(0) : tosBytes.toEthSignedMessageHash();
    getGroupTOSHash[group] = tosHash;
    emit TOSUpdated(group, tosBytes);
  }
}
