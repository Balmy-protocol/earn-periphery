// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "../base/Clone.sol";
import { IDelayedWithdrawalAdapter } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { LidoSTETHConnector } from "src/strategies/layers/connector/lido/LidoSTETHConnector.sol";
import { ExternalFees } from "../../layers/fees/external/ExternalFees.sol";
import { ExternalCreationValidation } from "../../layers/creation-validation/external/ExternalCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { BaseDelayedStrategy } from "../base/BaseDelayedStrategy.sol";

contract LidoSTETHStrategy is
  BaseDelayedStrategy,
  Clone,
  LidoSTETHConnector,
  ExternalLiquidityMining,
  ExternalFees,
  ExternalCreationValidation
{
  /// @inheritdoc IEarnStrategy
  string public description;

  // slither-disable-next-line reentrancy-benign
  function initAndRegister(
    address owner,
    bytes calldata creationValidationData,
    bytes calldata feesData,
    string calldata description_
  )
    external
    returns (StrategyId strategyId_)
  {
    strategyId_ = _baseStrategy_registerStrategy(owner);
    init(creationValidationData, feesData, description_);
  }

  // slither-disable-next-line reentrancy-benign
  function initWithId(
    StrategyId strategyId_,
    bytes calldata creationValidationData,
    bytes calldata feesData,
    string calldata description_
  )
    external
  {
    _strategyId = strategyId_;
    init(creationValidationData, feesData, description_);
  }

  // slither-disable-next-line reentrancy-benign
  function init(
    bytes calldata creationValidationData,
    bytes calldata feesData,
    string calldata description_
  )
    public
    initializer
  {
    _creationValidation_init(creationValidationData);
    _fees_init(feesData);
    description = description_;
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
    override(ExternalFees, ExternalLiquidityMining, ExternalCreationValidation)
    returns (IGlobalEarnRegistry)
  {
    return IGlobalEarnRegistry(_getArgAddress(20));
  }

  function strategyId()
    public
    view
    override(BaseDelayedStrategy, ExternalFees, ExternalLiquidityMining, ExternalCreationValidation)
    returns (StrategyId)
  {
    return BaseDelayedStrategy.strategyId();
  }

  function _earnVault() internal view override returns (IEarnVault) {
    return IEarnVault(_getArgAddress(0));
  }
}
