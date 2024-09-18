// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

/// @notice Interface for the Guardian Manager that the strategies call
interface IGuardianManagerCore {
  /**
   * @notice Returns if the given account has permissions to start a rescue
   */
  function canStartRescue(StrategyId strategyId, address account) external view returns (bool);
  /**
   * @notice Returns if the given account has permissions to cancel a rescue
   */
  function canCancelRescue(StrategyId strategyId, address account) external view returns (bool);
  /**
   * @notice Returns if the given account has permissions to confirm a rescue
   */
  function canConfirmRescue(StrategyId strategyId, address account) external view returns (bool);

  /// @notice Allow the strategy to call the manager, for self-configuration
  function strategySelfConfigure(bytes calldata data) external;

  /**
   * @notice Starts a rescue
   * @dev Will revert if the rescue is already in progress or if it has been confirmed already
   */
  function startRescue(StrategyId strategyId, address feeRecipient) external;
  /**
   * @notice Cancels a rescue
   * @dev Will revert if the rescue is not in progress
   */
  function cancelRescue(StrategyId strategyId) external;
  /**
   * @notice Confirms a rescue
   * @dev Will revert if the rescue is not in progress
   */
  function confirmRescue(StrategyId strategyId) external returns (address feeRecipient, uint16 rescueFeeBps);
}
