// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

/// @notice Interface for the Creation Validation Manager that the strategies call
interface ICreationValidationManagerCore {
  /// @notice Validates a position creation for the given strategy
  function validatePositionCreation(StrategyId strategyId, address sender, bytes calldata data) external view;

  /**
   * @notice Allows the strategy to call the manager, for self-configuration
   */
  function strategySelfConfigure(bytes calldata data) external;
}
