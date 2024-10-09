// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { BaseLiquidityMining } from "./base/BaseLiquidityMining.sol";
import { IEarnStrategy, StrategyId, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { ILiquidityMiningManagerCore } from "src/interfaces/ILiquidityMiningManager.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract ExternalLiquidityMining is BaseLiquidityMining, Initializable {
  using Math for uint256;

  /// @notice The id for the Liquidity Mining Manager
  bytes32 public constant LIQUIDITY_MINING_MANAGER = keccak256("LIQUIDITY_MINING_MANAGER");

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_init(bytes calldata data) internal onlyInitializing {
    ILiquidityMiningManagerCore manager = _getLiquidityMiningManager();
    manager.strategySelfConfigure(data);
  }

  // slither-disable-start assembly
  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_allTokens() internal view override returns (address[] memory tokens) {
    address[] memory underlyingTokens = _liquidity_mining_underlying_allTokens();
    ILiquidityMiningManagerCore manager = _getLiquidityMiningManager();
    address[] memory rewardsTokens = manager.rewards(strategyId());
    tokens = new address[](underlyingTokens.length + rewardsTokens.length);
    for (uint256 i; i < underlyingTokens.length; ++i) {
      tokens[i] = underlyingTokens[i];
    }
    uint256 tokensIndex = underlyingTokens.length;
    for (uint256 i; i < rewardsTokens.length; ++i) {
      address rewardToken = rewardsTokens[i];
      (bool isRepeated,) = _isRepeated(rewardToken, underlyingTokens);
      if (!isRepeated) {
        tokens[tokensIndex++] = rewardToken;
      }
    }
    if (tokensIndex < tokens.length) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        mstore(tokens, tokensIndex)
      }
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    (address[] memory underlyingTokens, uint256[] memory underlyingBalances) =
      _liquidity_mining_underlying_totalBalances();
    (tokens, balances) = _combineArraysWithRewards(underlyingTokens, underlyingBalances);
  }
  // slither-disable-end assembly

  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  {
    assetsDeposited = _liquidity_mining_underlying_deposited(depositToken, depositAmount);
    ILiquidityMiningManagerCore manager = _getLiquidityMiningManager();
    manager.deposited(strategyId(), assetsDeposited);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_withdraw(
    uint256 positionId,
    address[] calldata tokens,
    uint256[] calldata toWithdraw,
    address recipient
  )
    internal
    override
    returns (IEarnStrategy.WithdrawalType[] memory types)
  {
    // In this case, we will try to use the balance of the liquidity mining manager first,
    // and withdraw the rest from the underlying layer
    StrategyId strategyId_ = strategyId();
    ILiquidityMiningManagerCore manager = _getLiquidityMiningManager();
    address[] memory underlyingTokens = _liquidity_mining_underlying_allTokens();
    uint256[] memory toWithdrawUnderlying = new uint256[](underlyingTokens.length);
    uint256 toWithdrawAsset = toWithdraw[0];
    bool shouldWithdrawUnderlying = toWithdrawAsset > 0;
    for (uint256 i = 1; i < tokens.length; ++i) {
      uint256 toWithdrawToken = toWithdraw[i];
      uint256 balance = manager.rewardAmount(strategyId_, tokens[i]);
      uint256 toTransfer = Math.min(balance, toWithdrawToken);
      if (toTransfer > 0) {
        manager.claim(strategyId_, tokens[i], toTransfer, recipient);
      }
      if (i < underlyingTokens.length) {
        toWithdrawUnderlying[i] = toWithdrawToken - toTransfer;
        if (toWithdrawUnderlying[i] > 0) {
          shouldWithdrawUnderlying = true;
        }
      }
    }
    if (shouldWithdrawUnderlying) {
      if (toWithdrawAsset > 0) {
        // Only call withdrew if we are withdrawing the asset
        manager.withdrew(strategyId_, toWithdrawAsset);
      }
      toWithdrawUnderlying[0] = toWithdrawAsset;
      _liquidity_mining_underlying_withdraw(positionId, underlyingTokens, toWithdrawUnderlying, recipient);
    }
    return _liquidity_mining_supportedWithdrawals();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    (balanceChanges, actualWithdrawnTokens, actualWithdrawnAmounts, result) =
      _liquidity_mining_underlying_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
    ILiquidityMiningManagerCore manager = _getLiquidityMiningManager();
    manager.withdrew(strategyId(), balanceChanges[0]);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_supportedWithdrawals()
    internal
    view
    override
    returns (IEarnStrategy.WithdrawalType[] memory supportedWithdrawals)
  {
    IEarnStrategy.WithdrawalType[] memory underlyingSupportedWithdrawals =
      _liquidity_mining_underlying_supportedWithdrawals();
    address[] memory tokens = _liquidity_mining_allTokens();
    supportedWithdrawals = new IEarnStrategy.WithdrawalType[](tokens.length);
    for (uint256 i; i < underlyingSupportedWithdrawals.length; ++i) {
      supportedWithdrawals[i] = underlyingSupportedWithdrawals[i];
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_maxWithdraw()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    (address[] memory underlyingTokens, uint256[] memory underlyingWithdrawable) =
      _liquidity_mining_underlying_maxWithdraw();
    (tokens, withdrawable) = _combineArraysWithRewards(underlyingTokens, underlyingWithdrawable);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _liquidity_mining_rewardEmissionsPerSecondPerAsset()
    internal
    view
    override
    returns (uint256[] memory emissions, uint256[] memory multipliers)
  {
    StrategyId strategyId_ = strategyId();
    ILiquidityMiningManagerCore manager = _getLiquidityMiningManager();

    // Fetch underlying data
    (uint256[] memory underlyingEmissions, uint256[] memory underlyingMultipliers) =
      _liquidity_mining_underlying_rewardEmissionsPerSecondPerAsset();
    (address[] memory underlyingTokens, uint256[] memory balances) = _liquidity_mining_underlying_totalBalances();

    // Fetch all reward tokens
    address[] memory rewardsTokens = manager.rewards(strategyId_);

    // Build arrays
    emissions = new uint256[](underlyingEmissions.length + rewardsTokens.length);
    multipliers = new uint256[](underlyingEmissions.length + rewardsTokens.length);

    // Load underlying values
    for (uint256 i; i < underlyingEmissions.length; ++i) {
      emissions[i] = underlyingEmissions[i];
      multipliers[i] = underlyingMultipliers[i];
    }

    // Add liquidity mining data
    uint256 index = underlyingEmissions.length;
    uint256 totalAssets = Math.max(balances[0], 1);
    for (uint256 i; i < rewardsTokens.length; ++i) {
      address rewardToken = rewardsTokens[i];
      (uint256 emissionPerSecond, uint256 deadline) = manager.campaignEmission(strategyId_, rewardToken);
      if (block.timestamp > deadline) continue;
      (bool isRepeated, uint256 indexRepeated) = _isRepeated(rewardToken, underlyingTokens);
      if (isRepeated) {
        emissions[indexRepeated] +=
          emissionPerSecond.mulDiv(underlyingMultipliers[i - 1], totalAssets, Math.Rounding.Floor);
      } else {
        emissions[index] = emissionPerSecond.mulDiv(1e30, totalAssets, Math.Rounding.Floor);
        multipliers[index++] = 1e30;
      }
    }

    if (index < emissions.length) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        mstore(emissions, index)
        mstore(multipliers, index)
      }
    }
  }

  // slither-disable-next-line dead-code
  function _getLiquidityMiningManager() private view returns (ILiquidityMiningManagerCore) {
    return ILiquidityMiningManagerCore(globalRegistry().getAddressOrFail(LIQUIDITY_MINING_MANAGER));
  }

  // slither-disable-next-line dead-code
  function _isRepeated(address token, address[] memory tokens) private pure returns (bool isRepeated, uint256 index) {
    // The asset and can't be repeated, so we start from next index
    for (uint256 i = 1; i < tokens.length; ++i) {
      if (tokens[i] == token) {
        return (true, i);
      }
    }
    return (false, 0);
  }

  // slither-disable-start assembly
  // slither-disable-next-line dead-code
  function _combineArraysWithRewards(
    address[] memory underlyingTokens,
    uint256[] memory underlyingAmounts
  )
    private
    view
    returns (address[] memory tokens, uint256[] memory amounts)
  {
    StrategyId strategyId_ = strategyId();
    ILiquidityMiningManagerCore manager = _getLiquidityMiningManager();
    address[] memory rewardsTokens = manager.rewards(strategyId_);
    tokens = new address[](underlyingTokens.length + rewardsTokens.length);
    amounts = new uint256[](underlyingTokens.length + rewardsTokens.length);
    for (uint256 i; i < underlyingTokens.length; ++i) {
      tokens[i] = underlyingTokens[i];
      amounts[i] = underlyingAmounts[i];
    }
    uint256 tokensIndex = underlyingTokens.length;
    for (uint256 i; i < rewardsTokens.length; ++i) {
      address rewardToken = rewardsTokens[i];
      uint256 rewardAmount = manager.rewardAmount(strategyId_, rewardToken);
      (bool isRepeated, uint256 indexRepeated) = _isRepeated(rewardToken, underlyingTokens);
      if (isRepeated) {
        amounts[indexRepeated] += rewardAmount;
      } else {
        tokens[tokensIndex] = rewardToken;
        amounts[tokensIndex++] = rewardAmount;
      }
    }
    if (tokensIndex < tokens.length) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        mstore(tokens, tokensIndex)
        mstore(amounts, tokensIndex)
      }
    }
  }
  // slither-disable-end assembly
}
