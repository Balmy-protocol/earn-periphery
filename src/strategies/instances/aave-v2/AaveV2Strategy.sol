// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "@clones/Clone.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { AaveV2Connector, IAToken, IERC20, IAaveV2Pool } from "../../layers/connector/AaveV2Connector.sol";
import { ExternalFees } from "../../layers/fees/external/ExternalFees.sol";
import { ExternalGuardian } from "../../layers/guardian/external/ExternalGuardian.sol";
import { ExternalTOSCreationValidation } from
  "../../layers/creation-validation/external/ExternalTOSCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { BaseStrategy } from "../base/BaseStrategy.sol";

contract AaveV2Strategy is
  BaseStrategy,
  Clone,
  AaveV2Connector,
  ExternalLiquidityMining,
  ExternalFees,
  ExternalGuardian,
  ExternalTOSCreationValidation
{
  /// @inheritdoc IEarnStrategy
  string public description;

  // slither-disable-next-line reentrancy-benign
  function initAndRegister(
    address owner,
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description_
  )
    external
    returns (StrategyId strategyId_)
  {
    strategyId_ = _baseStrategy_registerStrategy(owner);
    init(creationValidationData, guardianData, feesData, description_);
  }

  // slither-disable-next-line reentrancy-benign
  function initWithId(
    StrategyId strategyId_,
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description_
  )
    external
  {
    _strategyId = strategyId_;
    init(creationValidationData, guardianData, feesData, description_);
  }

  // slither-disable-next-line reentrancy-benign
  function init(
    bytes calldata creationValidationData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description_
  )
    public
    initializer
  {
    _creationValidation_init(creationValidationData);
    _guardian_init(guardianData);
    _fees_init(feesData);
    _connector_init();
    description = description_;
  }

  function strategyId()
    public
    view
    override(ExternalLiquidityMining, ExternalFees, ExternalGuardian, ExternalTOSCreationValidation, BaseStrategy)
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

  function _earnVault() internal pure override returns (IEarnVault) {
    return IEarnVault(_getArgAddress(0));
  }

  function globalRegistry()
    public
    pure
    override(ExternalLiquidityMining, ExternalFees, ExternalGuardian, ExternalTOSCreationValidation)
    returns (IGlobalEarnRegistry)
  {
    return IGlobalEarnRegistry(_getArgAddress(20));
  }

  function aToken() public pure override returns (IAToken) {
    return IAToken(_getArgAddress(40));
  }

  function _asset() internal pure override returns (IERC20) {
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
