// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

/**
 * @title TOS Manager Interface
 * @notice This manager handles TOS for the strategies that call it
 */
interface ITOSManager {
  /// @notice Emitted when the TOS is updated for a group
  event TOSUpdated(bytes32 group, bytes tos);

  /// @notice Emitted when a strategy is assigned to a group
  event StrategyAssignedToGroup(StrategyId strategyId, bytes32 group);

  /// @notice Thrown when an invalid TOS signature is provided
  error InvalidTOSSignature();

  /**
   * @notice Returns the role in charge of managing all TOS
   * @return The role in charge of managing all TOS
   */
  // slither-disable-next-line naming-convention
  function MANAGE_TOS_ROLE() external view returns (bytes32);

  /// @notice Returns the strategy's TOS hash. If empty, then the strategy does not have TOS assigned
  function getStrategyTOSHash(StrategyId strategyId) external view returns (bytes32);

  /// @notice Returns the strategy's group id. If empty, then the strategy does not have a group assigned
  function getStrategyGroup(StrategyId strategyId) external view returns (bytes32);

  /// @notice Returns the group's TOS hash. If empty, then the group does not have TOS assigned
  function getGroupTOSHash(bytes32 group) external view returns (bytes32);

  /// @notice Validates a position creation for the given strategy
  function validatePositionCreation(StrategyId strategyId, address sender, bytes calldata signature) external view;

  /// @notice Updates the TOS for a specific group
  function updateTOS(bytes32 group, bytes calldata tos) external;

  /**
   * @notice Assigns a strategy to a group
   * @dev The caller must be have the manage role, or must be the strategy
   * @param strategyId The strategy to assign
   * @param group The group to assign the strategy to
   */
  function assignStrategyToGroup(StrategyId strategyId, bytes32 group) external;
}
