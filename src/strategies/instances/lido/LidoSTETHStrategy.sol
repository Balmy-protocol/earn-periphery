// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "../base/Clone.sol";
import { IDelayedWithdrawalAdapter } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { LidoSTETHConnector } from "src/strategies/layers/connector/lido/LidoSTETHConnector.sol";
import { ExternalFees } from "../../layers/fees/external/ExternalFees.sol";
import { RegistryBasedCreationValidation } from
  "../../layers/creation-validation/external/RegistryBasedCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { BaseDelayedStrategy } from "../base/BaseDelayedStrategy.sol";

contract LidoSTETHStrategy is
  BaseDelayedStrategy,
  Clone,
  LidoSTETHConnector,
  ExternalLiquidityMining,
  ExternalFees,
  RegistryBasedCreationValidation
{
  // slither-disable-next-line reentrancy-benign
  function initAndRegister(
    address owner,
    bytes calldata creationValidationData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData
  )
    external
    returns (StrategyId strategyId_)
  {
    strategyId_ = _baseStrategy_registerStrategy(owner);
    init({ creationValidationData: creationValidationData, feesData: feesData, liquidityMiningData: liquidityMiningData });
  }

  // slither-disable-next-line reentrancy-benign
  function initWithId(
    StrategyId strategyId_,
    bytes calldata creationValidationData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData
  )
    external
  {
    _strategyId = strategyId_;
    init({ creationValidationData: creationValidationData, feesData: feesData, liquidityMiningData: liquidityMiningData });
  }

  // slither-disable-next-line reentrancy-benign
  function init(
    bytes calldata creationValidationData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData
  )
    public
    initializer
  {
    _creationValidation_init(creationValidationData);
    _fees_init(feesData);
    _liquidity_mining_init(liquidityMiningData);
  }

  // Immutable params:
  // 1. Earn Vault (20B)                 - _getArgAddress(0)
  // 2. Global Registry (20B)            - _getArgAddress(20)
  // 3. Delayed Withdrawal Adapter (20B) - _getArgAddress(40)

  function _delayedWithdrawalAdapter() internal view override returns (IDelayedWithdrawalAdapter) {
    return IDelayedWithdrawalAdapter(_getArgAddress(40));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_underlying_asset() internal pure override returns (address asset) {
    return _connector_asset();
  }

  function globalRegistry()
    public
    view
    override(ExternalFees, ExternalLiquidityMining, RegistryBasedCreationValidation)
    returns (IGlobalEarnRegistry)
  {
    return IGlobalEarnRegistry(_getArgAddress(20));
  }

  function strategyId()
    public
    view
    override(BaseDelayedStrategy, ExternalFees, ExternalLiquidityMining, RegistryBasedCreationValidation)
    returns (StrategyId)
  {
    return BaseDelayedStrategy.strategyId();
  }

  function _earnVault() internal view override returns (IEarnVault) {
    return IEarnVault(_getArgAddress(0));
  }

  // slither-disable-next-line naming-convention
  function _fees_underlying_supportedWithdrawals()
    internal
    view
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return _connector_supportedWithdrawals();
  }
}
