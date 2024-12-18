// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "../base/Clone.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { ERC4626Connector } from "../../layers/connector/ERC4626Connector.sol";
import { ExternalFees } from "../../layers/fees/external/ExternalFees.sol";
import { ExternalGuardian } from "../../layers/guardian/external/ExternalGuardian.sol";
import { RegistryBasedCreationValidation } from
  "../../layers/creation-validation/external/RegistryBasedCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { BaseStrategy } from "../base/BaseStrategy.sol";

contract ERC4626Strategy is
  BaseStrategy,
  Clone,
  ERC4626Connector,
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
    override(ExternalLiquidityMining, ExternalFees, ExternalGuardian, RegistryBasedCreationValidation, BaseStrategy)
    returns (StrategyId)
  {
    return BaseStrategy.strategyId();
  }

  // Immutable params:
  // 1. Earn Vault (20B)
  // 2. Global Registry (20B)
  // 3. ERC4626 vault (20B)
  // 4. Asset (20B)

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

  // slither-disable-next-line naming-convention
  function ERC4626Vault() public view override returns (IERC4626) {
    return IERC4626(_getArgAddress(40));
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
}
