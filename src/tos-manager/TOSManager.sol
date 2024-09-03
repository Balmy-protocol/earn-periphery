// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { ITOSManager, IEarnStrategyRegistry, StrategyId } from "../interfaces/ITOSManager.sol";

contract TOSManager is ITOSManager, AccessControlDefaultAdminRules {
  using MessageHashUtils for bytes;

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
    address[] memory initialManageTOSdmins
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    STRATEGY_REGISTRY = registry;
    for (uint256 i; i < initialManageTOSdmins.length; ++i) {
      _grantRole(MANAGE_TOS_ROLE, initialManageTOSdmins[i]);
    }
  }

  /// @inheritdoc ITOSManager
  function getStrategyTOSHash(StrategyId strategyId) public view returns (bytes32) {
    bytes32 group = getStrategyGroup[strategyId];
    if (group == bytes32(0)) return bytes32(0);
    return getGroupTOSHash[group];
  }

  /// @inheritdoc ITOSManager
  function validatePositionCreation(StrategyId strategyId, address sender, bytes calldata signature) external view {
    bytes32 tosHash = getStrategyTOSHash(strategyId);
    if (tosHash != bytes32(0) && !SignatureChecker.isValidSignatureNow(sender, tosHash, signature)) {
      revert InvalidTOSSignature();
    }
  }

  /// @inheritdoc ITOSManager
  function updateTOS(bytes32 group, bytes calldata tos) external onlyRole(MANAGE_TOS_ROLE) {
    bytes32 tosHash = tos.length == 0 ? bytes32(0) : tos.toEthSignedMessageHash();
    getGroupTOSHash[group] = tosHash;
    emit TOSUpdated(group, tos);
  }

  /// @inheritdoc ITOSManager
  function assignStrategyToGroup(StrategyId strategyId, bytes32 group) external {
    // Note: the caller must either have the manage role, or it must be the actual strategy
    if (!hasRole(MANAGE_TOS_ROLE, msg.sender) && msg.sender != address(STRATEGY_REGISTRY.getStrategy(strategyId))) {
      revert UnauthorizedCaller();
    }
    getStrategyGroup[strategyId] = group;
    emit StrategyAssignedToGroup(strategyId, group);
  }
}
