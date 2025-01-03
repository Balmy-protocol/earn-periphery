// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "../base/Clone.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { AaveV2Connector, IAToken, IERC20, IAaveV2Pool } from "../../layers/connector/AaveV2Connector.sol";
import { ExternalFees } from "../../layers/fees/external/ExternalFees.sol";
import { ExternalGuardian } from "../../layers/guardian/external/ExternalGuardian.sol";
import { RegistryBasedCreationValidation } from
  "../../layers/creation-validation/external/RegistryBasedCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { BaseStrategy } from "../base/BaseStrategy.sol";

contract AaveV2Strategy is
  BaseStrategy,
  Clone,
  AaveV2Connector,
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
  // 1. Earn Vault (20B)        - _getArgAddress(0)
  // 2. Global Registry (20B)   - _getArgAddress(20)
  // 3. AaveV2 aToken (20B)      - _getArgAddress(40)
  // 4. Asset (20B)             - _getArgAddress(60)
  // 5. AaveV2 pool (20B)       - _getArgAddress(80)

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

  function aToken() public view override returns (IAToken) {
    return IAToken(_getArgAddress(40));
  }

  function _asset() internal view override returns (IERC20) {
    return IERC20(_getArgAddress(60));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_underlying_asset() internal view override returns (address asset) {
    return _connector_asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_rescueFee() internal view override returns (uint16) {
    return _getFees().rescueFee;
  }

  function pool() public view virtual override returns (IAaveV2Pool) {
    return IAaveV2Pool(_getArgAddress(80));
  }
}
