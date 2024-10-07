// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IDelayedWithdrawalAdapter } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { LidoSTETHConnector } from "src/strategies/layers/connector/LidoSTETHConnector.sol";
import { ExternalFees } from "../../layers/fees/ExternalFees.sol";
import { ExternalTOSCreationValidation } from "../../layers/creation-validation/ExternalTOSCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/ExternalLiquidityMining.sol";
import { BaseDelayedStrategy } from "../base/BaseDelayedStrategy.sol";

contract LidoSTETHStrategy is
  BaseDelayedStrategy,
  LidoSTETHConnector,
  ExternalLiquidityMining,
  ExternalFees,
  ExternalTOSCreationValidation
{
  /// @inheritdoc IEarnStrategy
  string public description;

  // slither-disable-start naming-convention
  IDelayedWithdrawalAdapter internal immutable __delayedWithdrawalAdapter;
  IGlobalEarnRegistry internal immutable _globalRegistry;
  IEarnVault internal immutable _vault;
  // slither-disable-end naming-convention

  constructor(
    // General
    IGlobalEarnRegistry globalRegistry_,
    IEarnVault vault_,
    string memory description_,
    IDelayedWithdrawalAdapter delayedWithdrawalAdapter_
  ) {
    _globalRegistry = globalRegistry_;
    _vault = vault_;
    description = description_;
    __delayedWithdrawalAdapter = delayedWithdrawalAdapter_;
  }

  function _delayedWithdrawalAdapter() internal view override returns (IDelayedWithdrawalAdapter) {
    return __delayedWithdrawalAdapter;
  }

  function _fees_underlying_asset() internal pure override returns (address asset) {
    return _connector_asset();
  }

  function globalRegistry()
    public
    view
    override(ExternalFees, ExternalLiquidityMining, ExternalTOSCreationValidation)
    returns (IGlobalEarnRegistry)
  {
    return _globalRegistry;
  }

  function strategyId()
    public
    view
    override(BaseDelayedStrategy, ExternalFees, ExternalLiquidityMining, ExternalTOSCreationValidation)
    returns (StrategyId)
  {
    return BaseDelayedStrategy.strategyId();
  }

  function _earnVault() internal view override returns (IEarnVault) {
    return _vault;
  }
}
