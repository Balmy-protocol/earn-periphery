// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { BaseLiquidityMining } from "./base/BaseLiquidityMining.sol";
import { IEarnStrategy, StrategyId, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { ILiquidityMiningManagerCore } from "src/interfaces/ILiquidityMiningManager.sol";

abstract contract ExternalLiquidityMining is BaseLiquidityMining, Initializable {
  /// @notice The id for the Liquidity Mining Manager
  bytes32 public constant LIQUIDITY_MINING_MANAGER = keccak256("LIQUIDITY_MINING_MANAGER");

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

  mapping(address token => uint256 index) internal _underlyingTokens;

  function _liquidity_mining_init() internal onlyInitializing {
    address[] memory underlyingTokens = _liquidity_mining_underlying_allTokens();
    for (uint256 i; i < underlyingTokens.length; ++i) {
      _underlyingTokens[underlyingTokens[i]] = i + 1; // 0 is reserved for false
    }
  }

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
      bool isRepeated;
      if (_underlyingTokens[rewardToken] == 0) {
        for (uint256 j = 1; j < underlyingTokens.length; ++j) {
          if (underlyingTokens[j] == rewardToken) {
            isRepeated = true;
            break;
          }
        }
      } else {
        isRepeated = true;
      }

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

  function _liquidity_mining_totalBalances()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    (address[] memory underlyingTokens, uint256[] memory underlyingBalances) =
      _liquidity_mining_underlying_totalBalances();
    ILiquidityMiningManagerCore manager = _getLiquidityMiningManager();
    address[] memory rewardsTokens = manager.rewards(strategyId());
    tokens = new address[](underlyingTokens.length + rewardsTokens.length);
    balances = new uint256[](underlyingTokens.length + rewardsTokens.length);
    for (uint256 i; i < underlyingTokens.length; ++i) {
      tokens[i] = underlyingTokens[i];
      balances[i] = underlyingBalances[i];
    }
    uint256 tokensIndex = underlyingTokens.length;
    for (uint256 i; i < rewardsTokens.length; ++i) {
      address rewardToken = rewardsTokens[i];
      uint256 rewardAmount = manager.rewardAmount(strategyId(), rewardToken);
      uint256 indexRepeated;
      if (_underlyingTokens[rewardToken] == 0) {
        for (uint256 j = 1; j < underlyingTokens.length; ++j) {
          if (underlyingTokens[j] == rewardToken) {
            indexRepeated = j;
            break;
          }
        }
      } else {
        indexRepeated = _underlyingTokens[rewardToken] - 1;
      }

      if (indexRepeated != 0) {
        balances[indexRepeated] += rewardAmount;
      } else {
        tokens[tokensIndex] = rewardToken;
        balances[tokensIndex] = rewardAmount;
        tokensIndex++;
      }
    }
    if (tokensIndex < tokens.length) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        mstore(tokens, tokensIndex)
        mstore(balances, tokensIndex)
      }
    }
  }

  function _liquidity_mining_withdraw(
    uint256 positionId,
    address[] calldata tokens,
    uint256[] calldata toWithdraw,
    address recipient
  )
    internal
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory types)
  // solhint-disable-next-line no-empty-blocks
  { }

  function _liquidity_mining_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    virtual
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  // solhint-disable-next-line no-empty-blocks
  { }

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

  function _getLiquidityMiningManager() private view returns (ILiquidityMiningManagerCore) {
    return ILiquidityMiningManagerCore(globalRegistry().getAddressOrFail(LIQUIDITY_MINING_MANAGER));
  }
}
