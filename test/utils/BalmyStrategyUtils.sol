// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IEarnStrategyRegistry, StrategyId, IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategyRegistry.sol";
import { EarnBalmyStrategyStateBalanceMock } from "../mocks/strategies/EarnBalmyStrategyStateBalanceMock.sol";

/// @notice Utility functions for deploying Balmy strategies in tests
library BalmyStrategyUtils {
  function deployBalmyStrategy(address[] memory tokens) internal returns (EarnBalmyStrategyStateBalanceMock strategy) {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return strategy = new EarnBalmyStrategyStateBalanceMock(tokens, withdrawalTypes);
  }

  function deployBalmyStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens
  )
    internal
    returns (StrategyId strategyId, EarnBalmyStrategyStateBalanceMock strategy)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return deployBalmyStrategy(registry, tokens, withdrawalTypes);
  }

  function deployBalmyStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes
  )
    internal
    returns (StrategyId strategyId, EarnBalmyStrategyStateBalanceMock strategy)
  {
    require(tokens.length > 0, "Invalid");
    strategy = new EarnBalmyStrategyStateBalanceMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(address(this), strategy);
  }
}
