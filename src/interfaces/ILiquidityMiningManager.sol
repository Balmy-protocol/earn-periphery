// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
/**
 * @title Liquidity Mining Manager Core Interface
 * @notice This contract will manage the liquidity mining rewards for the strategies
 *          that are using it. It will keep track of the rewards that are available for
 *          each strategy, and will allow the strategies to claim them
 * @dev This interface is meant to be used by the strategies
 */

interface ILiquidityMiningManagerCore {
  /**
   * @notice Returns the tokens rewards for a given strategy
   * @param strategyId The id of the strategy
   * @return An array of tokens that are rewards for the given strategy
   */
  function rewards(StrategyId strategyId) external view returns (address[] memory);

  /**
   * @notice Returns the amount of rewards for a given strategy and token
   * @param strategyId The id of the strategy
   * @param token The token to get the rewards for
   */
  function rewardAmount(StrategyId strategyId, address token) external view returns (uint256);

  /**
   * @notice Claims the rewards for a given strategy and token, and sends them to the recipient
   * @param strategyId The id of the strategy
   * @param tokens The tokens to claim
   * @param amounts The amounts to claim
   * @param recipient The recipient of the rewards
   */
  function claim(StrategyId strategyId, address[] memory tokens, uint256[] memory amounts, address recipient) external;

  /**
   * @notice Alerts that a deposit has been made to the strategy
   * @param strategyId The id of the strategy
   * @param assetsDeposited The amount of assets deposited
   */
  function deposited(StrategyId strategyId, uint256 assetsDeposited) external;

  /**
   * @notice Alerts that a withdrawal has been made from the strategy
   * @param strategyId The id of the strategy
   * @param assetsWithdrawn The amount of assets withdrew
   */
  function withdrew(StrategyId strategyId, uint256 assetsWithdrawn) external;
}

/**
 * @title Liquidity Mining Manager Interface
 * @dev This interface is meant to be used by the strategies
 *      and for those address who has the permission to manage the liquidity mining rewards campaigns
 */
// solhint-disable-next-line no-empty-blocks
interface ILiquidityMiningManager is ILiquidityMiningManagerCore {
// TODO: add campaign management functions
}