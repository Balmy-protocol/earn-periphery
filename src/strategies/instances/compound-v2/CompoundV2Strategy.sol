// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "../base/Clone.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import {
  CompoundV2Connector,
  IERC20,
  ICERC20,
  IComptroller
} from "../../layers/connector/compound-v2/CompoundV2Connector.sol";
import { ExternalFees } from "../../layers/fees/external/ExternalFees.sol";
import { ExternalGuardian } from "../../layers/guardian/external/ExternalGuardian.sol";
import { RegistryBasedCreationValidation } from
  "../../layers/creation-validation/external/RegistryBasedCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { BaseStrategy } from "../base/BaseStrategy.sol";

contract CompoundV2Strategy is
  BaseStrategy,
  Clone,
  CompoundV2Connector,
  ExternalLiquidityMining,
  ExternalFees,
  ExternalGuardian,
  RegistryBasedCreationValidation
{
  /// @inheritdoc IEarnStrategy
  string public description;

  // slither-disable-next-line reentrancy-benign
  function initAndRegister(
    address owner,
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData,
    string calldata description_
  )
    external
    returns (StrategyId strategyId_)
  {
    strategyId_ = _baseStrategy_registerStrategy(owner);
    init({
      creationValidationData: creationValidationData,
      guardianData: guardianData,
      feesData: feesData,
      liquidityMiningData: liquidityMiningData,
      description_: description_
    });
  }

  // slither-disable-next-line reentrancy-benign
  function initWithId(
    StrategyId strategyId_,
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData,
    string calldata description_
  )
    external
  {
    _strategyId = strategyId_;
    init({
      creationValidationData: creationValidationData,
      guardianData: guardianData,
      feesData: feesData,
      liquidityMiningData: liquidityMiningData,
      description_: description_
    });
  }

  // slither-disable-next-line reentrancy-benign
  function init(
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData,
    string calldata description_
  )
    public
    initializer
  {
    _connector_init();
    _creationValidation_init(creationValidationData);
    _guardian_init(guardianData);
    _fees_init(feesData);
    _liquidity_mining_init(liquidityMiningData);
    description = description_;
  }

  function strategyId()
    public
    view
    override(ExternalLiquidityMining, ExternalFees, ExternalGuardian, RegistryBasedCreationValidation, BaseStrategy)
    returns (StrategyId)
  {
    return BaseStrategy.strategyId();
  }

  // Immutable params:
  // 1. Earn Vault (20B)              - _getArgAddress(0)
  // 2. Global Registry (20B)         - _getArgAddress(20)
  // 3. Asset (20B)                   - _getArgAddress(40)
  // 4. CompoundV2 cToken (20B)       - _getArgAddress(60)
  // 5. CompoundV2 comptroller (20B)  - _getArgAddress(80)
  // 6. CompoundV2 comp (20B)         - _getArgAddress(100)

  function _earnVault() internal view override returns (IEarnVault) {
    return IEarnVault(_getArgAddress(0));
  }

  function globalRegistry()
    public
    view
    override(ExternalLiquidityMining, ExternalFees, ExternalGuardian, RegistryBasedCreationValidation)
    returns (IGlobalEarnRegistry)
  {
    return IGlobalEarnRegistry(_getArgAddress(20));
  }

  function _asset() internal view override returns (address) {
    return _getArgAddress(40);
  }

  function cToken() public view override returns (ICERC20) {
    return ICERC20(_getArgAddress(60));
  }

  function comptroller() public view override returns (IComptroller) {
    return IComptroller(_getArgAddress(80));
  }

  function comp() public view override returns (IERC20) {
    return IERC20(_getArgAddress(100));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_underlying_asset() internal view override returns (address asset) {
    return _connector_asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_rescueFee() internal view override returns (uint16) {
    return _getFees().rescueFee;
  }
}
