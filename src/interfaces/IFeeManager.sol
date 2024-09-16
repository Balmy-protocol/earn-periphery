// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Fees } from "../types/Fees.sol";

/**
 * @title Fee Manager Interface
 * @notice This manager handles fees for the strategies that call it
 */
interface IFeeManager {
  /// @notice Thrown when trying to set fees greater than the maximum fee
  error FeesGreaterThanMaximum();

  /**
   * @notice Emitted when a new default fees are set
   * @param fees The new fees
   */
  event DefaultFeesChanged(Fees fees);

  /**
   * @notice Emitted when a new strategy fees are set
   * @param strategy The strategy
   * @param fees The new fees
   */
  event StrategyFeesChanged(StrategyId strategy, Fees fees);

  /**
   * @notice Returns the role in charge of managing fees
   * @return The role in charge of managing fees
   */
  // slither-disable-next-line naming-convention
  function MANAGE_FEES_ROLE() external view returns (bytes32);

  /**
   * @notice Returns the role in charge of withdrawing fees
   * @return The role in charge of withdrawing fees
   */
  // slither-disable-next-line naming-convention
  function WITHDRAW_FEES_ROLE() external view returns (bytes32);

  /**
   * @notice Returns the max amount of fee possible
   * @return The max amount of fee possible
   */
  // slither-disable-next-line naming-convention
  function MAX_FEE() external view returns (uint16);

  /// @notice Allow the strategy to call the manager, for self-configuration
  function strategySelfConfigure(bytes calldata data) external;

  /**
   * @notice Returns the strategy fees
   * @param strategyId The strategy to get the fees for
   * @return The strategy fees
   */
  function getFees(StrategyId strategyId) external view returns (Fees memory);

  /// @notice Returns if the caller can withdraw fees from the strategy
  function canWithdrawFees(StrategyId strategyId, address caller) external view returns (bool);

  /**
   * @notice Updates the fees for a strategy
   * @param strategyId The strategy to update the fees for
   * @param newFees The new fees
   */
  function updateFees(StrategyId strategyId, Fees calldata newFees) external;

  /**
   * @notice Returns the default fees
   * @return The default fees
   */
  function defaultFees() external view returns (Fees memory);

  /**
   * @notice Sets the fees for a strategy to the default fees
   * @param strategyId The strategy to set the fees for
   */
  function setToDefault(StrategyId strategyId) external;

  /**
   * @notice Sets the default fees
   * @param newFees The new default fees
   */
  function setDefaultFees(Fees calldata newFees) external;

  /**
   * @notice Checks if a strategy has default fees
   * @param strategyId The strategy to check
   */
  function hasDefaultFees(StrategyId strategyId) external view returns (bool);
}
