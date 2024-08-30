// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ITOSManager, StrategyId } from "../interfaces/ITOSManager.sol";

contract TOSManager is ITOSManager, AccessControlDefaultAdminRules {
  using MessageHashUtils for bytes;

  /// @inheritdoc ITOSManager
  bytes32 public constant MANAGE_TOS_ROLE = keccak256("MANAGE_TOS_ROLE");
  /// @inheritdoc ITOSManager
  mapping(StrategyId strategyId => bytes32 group) public getStrategyGroup;
  /// @inheritdoc ITOSManager
  mapping(bytes32 group => bytes32 tosHash) public getGroupTOSHash;

  constructor(
    address superAdmin,
    address[] memory initialManageTOSdmins
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    for (uint256 i; i < initialManageTOSdmins.length; ++i) {
      _grantRole(MANAGE_TOS_ROLE, initialManageTOSdmins[i]);
    }
  }

  /// @inheritdoc ITOSManager
  // solhint-disable no-empty-blocks
  function getStrategyTOSHash(StrategyId strategyId) public view returns (bytes32) { }

  /// @inheritdoc ITOSManager
  // solhint-disable no-empty-blocks
  function validatePositionCreation(StrategyId strategyId, address sender, bytes calldata signature) external view { }

  /// @inheritdoc ITOSManager
  function updateTOS(bytes32 group, bytes calldata tos) external onlyRole(MANAGE_TOS_ROLE) {
    bytes32 tosHash = tos.length == 0 ? bytes32(0) : tos.toEthSignedMessageHash();
    getGroupTOSHash[group] = tosHash;
    emit TOSUpdated(group, tos);
  }

  /// @inheritdoc ITOSManager
  // solhint-disable no-empty-blocks
  function assignStrategyToGroup(StrategyId strategyId, bytes32 group) external { }
}
