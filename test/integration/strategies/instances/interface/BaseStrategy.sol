// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ExternalLiquidityMining } from "src/strategies/layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { ExternalFees } from "src/strategies/layers/fees/external/ExternalFees.sol";
import { ExternalGuardian } from "src/strategies/layers/guardian/external/ExternalGuardian.sol";
import { RegistryBasedCreationValidation } from
  "src/strategies/layers/creation-validation/external/RegistryBasedCreationValidation.sol";
import { IEarnBalmyStrategy } from "src/interfaces/IEarnBalmyStrategy.sol";
import { BaseConnector } from "src/strategies/layers/connector/base/BaseConnector.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { StrategyId } from "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";

abstract contract BaseStrategy is
  IEarnBalmyStrategy,
  BaseConnector,
  ExternalLiquidityMining,
  ExternalFees,
  ExternalGuardian,
  RegistryBasedCreationValidation
{
  function globalRegistry()
    public
    view
    virtual
    override(ExternalLiquidityMining, ExternalFees, ExternalGuardian, RegistryBasedCreationValidation)
    returns (IGlobalEarnRegistry)
  {
    return IGlobalEarnRegistry(address(0));
  }

  function strategyId()
    public
    view
    virtual
    override(ExternalLiquidityMining, ExternalFees, ExternalGuardian, RegistryBasedCreationValidation)
    returns (StrategyId)
  {
    return StrategyId.wrap(0);
  }
}
