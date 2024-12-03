// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { StrategyId, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
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
   * @notice Returns the emission per second and deadline for a given campaign
   * @param strategyId The id of the strategy
   * @param token The token to get the campaign for
   * @return emissionPerSecond The emission per second for the campaign
   * @return deadline The deadline for the campaign
   */
  function campaignEmission(
    StrategyId strategyId,
    address token
  )
    external
    view
    returns (uint256 emissionPerSecond, uint256 deadline);

  /**
   * @notice Claims the rewards for a given strategy and token, and sends them to the recipient
   * @param strategyId The id of the strategy
   * @param token The token to claim
   * @param amount The amount to claim
   * @param recipient The recipient of the rewards
   */
  function claim(StrategyId strategyId, address token, uint256 amount, address recipient) external;

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

  /// @notice Allows the strategy to call the manager, for self-configuration
  function strategySelfConfigure(bytes calldata data) external;
}

/**
 * @title Liquidity Mining Manager Interface
 * @dev This interface is meant to be used by the strategies
 *      and for those address who has the permission to manage the liquidity mining rewards campaigns
 */
// solhint-disable-next-line no-empty-blocks
interface ILiquidityMiningManager is ILiquidityMiningManagerCore {
  event CampaignSet(StrategyId indexed strategyId, address indexed reward, uint256 emissionPerSecond, uint256 deadline);
  event CampaignAborted(StrategyId indexed strategyId, address indexed reward);
  /**
   * @notice Returns the address of the strategy registry
   * @return The address of the strategy registry
   */
  // slither-disable-start naming-convention

  function STRATEGY_REGISTRY() external view returns (IEarnStrategyRegistry);
  /**
   * @notice Returns the role in charge of managing campaigns. Accounts with this role set campaigns
   * to individual strategies
   * @return The role in charge of managing campaigns
   */
  function MANAGE_CAMPAIGNS_ROLE() external view returns (bytes32);
  // slither-disable-end naming-convention

  /**
   * @notice Sets a campaign for a given strategy
   * @param strategyId The id of the strategy
   * @param reward The reward token for the campaign
   * @param emissionPerSecond The emission per second for the campaign
   * @param duration The duration of the campaign
   * @dev In the case of a native reward token, any excess funds will be returned to the caller
   */
  function setCampaign(
    StrategyId strategyId,
    address reward,
    uint256 emissionPerSecond,
    uint256 duration
  )
    external
    payable;

  function abortCampaign(StrategyId strategyId, address reward, address recipient) external;
}
