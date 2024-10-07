// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "@clones/Clone.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import {
  AaveV3Connector, IAToken, IERC20, IAaveV3Pool, IAaveV3Rewards
} from "../../layers/connector/AaveV3Connector.sol";
import { ExternalFees } from "../../layers/fees/ExternalFees.sol";
import { ExternalGuardian } from "../../layers/guardian/ExternalGuardian.sol";
import { ExternalTOSCreationValidation } from "../../layers/creation-validation/ExternalTOSCreationValidation.sol";
import { ExternalLiquidityMining } from "../../layers/liquidity-mining/ExternalLiquidityMining.sol";
import { BaseStrategy } from "../base/BaseStrategy.sol";

contract AaveV3Strategy is
  BaseStrategy,
  Clone,
  AaveV3Connector,
  ExternalLiquidityMining,
  ExternalFees,
  ExternalGuardian,
  ExternalTOSCreationValidation
{
  /// @inheritdoc IEarnStrategy
  string public description;

  // slither-disable-next-line reentrancy-benign
  function init(
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description_
  )
    external
    initializer
  {
    _creationValidation_init(tosData);
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
  // 3. AaveV3 vault (20B)      - _getArgAddress(40)
  // 4. Asset (20B)             - _getArgAddress(60)
  // 5. AaveV3 pool (20B)       - _getArgAddress(80)
  // 6. AaveV3 rewards (20B)    - _getArgAddress(100)

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

  function pool() public view virtual override returns (IAaveV3Pool) {
    return IAaveV3Pool(_getArgAddress(80));
  }

  function rewards() public view virtual override returns (IAaveV3Rewards) {
    return IAaveV3Rewards(_getArgAddress(100));
  }
}
