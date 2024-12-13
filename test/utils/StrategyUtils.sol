// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId } from "../../src/vault/EarnVault.sol";
import { IEarnStrategyRegistry } from "../../src/interfaces/IEarnStrategyRegistry.sol";
import { EarnStrategyStateBalanceMock } from "../mocks/strategies/EarnStrategyStateBalanceMock.sol";
import { EarnStrategyCustomBalanceMock } from "../mocks/strategies/EarnStrategyCustomBalanceMock.sol";
import { EarnStrategyStateBalanceBadMigrationMock } from
  "../mocks/strategies/EarnStrategyStateBalanceBadMigrationMock.sol";
import { EarnStrategyStateBalanceBadTokensMock } from "../mocks/strategies/EarnStrategyStateBalanceBadTokensMock.sol";

import { EarnStrategyStateBalanceBadPositionValidationMock } from
  "../mocks/strategies/EarnStrategyStateBalanceBadPositionValidationMock.sol";

import { ERC4626StrategyFactory } from "../../src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

import { IGlobalEarnRegistry } from "../../src/interfaces/IGlobalEarnRegistry.sol";

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

// struct ERC4626StrategyData {
//   IEarnVault earnVault; ✅
//   IGlobalEarnRegistry globalRegistry;
//   IERC4626 erc4626Vault; ✅
//   bytes creationValidationData;
//   bytes guardianData;
//   bytes feesData;
//   string description;
// }


library StrategyUtils {
  function deployStateStrategy( // @audit deploy stragety 
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    address owner
  )
    internal
    returns (EarnStrategyStateBalanceMock strategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);

    strategy = new EarnStrategyStateBalanceMock(tokens, withdrawalTypes);

    strategyId = registry.registerStrategy(owner, strategy);
  }

  function deployERC4626Strategy( // @audit deploy stragety 
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    address owner,
    IEarnStrategy strategy
  )
    internal
    returns (IEarnStrategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);

    strategyId = registry.registerStrategy(owner, strategy);

    return (strategy, strategyId);
  }

  function deployLIDOStrategy( // @audit deploy stragety 
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    address owner,
    IEarnStrategy strategy
  )
    internal
    returns (IEarnStrategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);

    strategyId = registry.registerStrategy(owner, strategy);

    return (strategy, strategyId);
  }

  function deployCompoundV2Strategy(IEarnStrategyRegistry registry,
    address[] memory tokens,
    address owner
  )
    internal
    returns (EarnStrategyStateBalanceMock strategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);

    strategyId = registry.registerStrategy(owner, strategy);

    return (strategy, strategyId);
  }

  function deployBadMigrationStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    address owner
  )
    internal
    returns (EarnStrategyStateBalanceBadMigrationMock strategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    strategy = new EarnStrategyStateBalanceBadMigrationMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(owner, strategy);
  }

  function deployBadPositionValidationStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens
  )
    internal
    returns (EarnStrategyStateBalanceBadPositionValidationMock strategy, StrategyId strategyId)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    strategy = new EarnStrategyStateBalanceBadPositionValidationMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(address(this), strategy);
  }

  function deployStateStrategy(address[] memory tokens) internal returns (EarnStrategyStateBalanceMock strategy) {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return strategy = new EarnStrategyStateBalanceMock(tokens, withdrawalTypes);
  }

  function deployBadTokensStrategy(address[] memory tokens) internal returns (EarnStrategyStateBalanceMock strategy) {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return strategy = new EarnStrategyStateBalanceBadTokensMock(tokens, withdrawalTypes);
  }

  function deployStateStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens
  )
    internal
    returns (StrategyId strategyId, EarnStrategyStateBalanceMock strategy)
  {
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = new IEarnStrategy.WithdrawalType[](tokens.length);
    return deployStateStrategy(registry, tokens, withdrawalTypes);
  }

  function deployStateStrategy(
    IEarnStrategyRegistry registry,
    address[] memory tokens,
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes
  )
    internal
    returns (StrategyId strategyId, EarnStrategyStateBalanceMock strategy)
  {
    require(tokens.length > 0, "Invalid");
    strategy = new EarnStrategyStateBalanceMock(tokens, withdrawalTypes);
    strategyId = registry.registerStrategy(address(this), strategy);
  }

  function deployCustomStrategy(
    IEarnStrategyRegistry registry,
    address asset
  )
    internal
    returns (StrategyId strategyId, EarnStrategyCustomBalanceMock strategy)
  {
    strategy = new EarnStrategyCustomBalanceMock(asset);
    strategyId = registry.registerStrategy(address(this), strategy);
  }
}
