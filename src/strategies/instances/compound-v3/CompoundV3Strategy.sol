// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "../base/Clone.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { CompoundV3Connector, ICERC20, ICometRewards } from "../../layers/connector/compound-v3/CompoundV3Connector.sol";
import { ExternalFees } from "../../layers/fees/external/ExternalFees.sol";
import { ExternalGuardian } from "../../layers/guardian/external/ExternalGuardian.sol";
import { RegistryBasedCreationValidation } from
  "../../layers/creation-validation/external/RegistryBasedCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { BaseStrategy } from "../base/BaseStrategy.sol";

contract CompoundV3Strategy is
  BaseStrategy,
  Clone,
  CompoundV3Connector,
  ExternalLiquidityMining,
  ExternalFees,
  ExternalGuardian,
  RegistryBasedCreationValidation
{
  // slither-disable-next-line reentrancy-benign
  function initAndRegister(
    address owner,
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData
  )
    external
    returns (StrategyId strategyId_)
  {
    strategyId_ = _baseStrategy_registerStrategy(owner);
    init({
      creationValidationData: creationValidationData,
      guardianData: guardianData,
      feesData: feesData,
      liquidityMiningData: liquidityMiningData
    });
  }

  // slither-disable-next-line reentrancy-benign
  function initWithId(
    StrategyId strategyId_,
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData
  )
    external
  {
    _strategyId = strategyId_;
    init({
      creationValidationData: creationValidationData,
      guardianData: guardianData,
      feesData: feesData,
      liquidityMiningData: liquidityMiningData
    });
  }

  // slither-disable-next-line reentrancy-benign
  function init(
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    bytes calldata liquidityMiningData
  )
    public
    initializer
  {
    _connector_init();
    _creationValidation_init(creationValidationData);
    _guardian_init(guardianData);
    _fees_init(feesData);
    _liquidity_mining_init(liquidityMiningData);
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
  // 4. CompoundV3 cToken (20B)       - _getArgAddress(60)
  // 5. CompoundV3 rewards (20B)      - _getArgAddress(80)

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

  function cometRewards() public view override returns (ICometRewards) {
    return ICometRewards(_getArgAddress(80));
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
