// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  IEarnStrategy, StrategyId, IEarnVault, SpecialWithdrawalCode
} from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IDelayedWithdrawalAdapter } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { ExternalFees } from "src/strategies/layers/fees/external/ExternalFees.sol";
import { ExternalTOSCreationValidation } from "src/strategies/layers/creation-validation/external/ExternalTOSCreationValidation.sol";
import { ExternalLiquidityMining } from "src/strategies/layers/liquidity-mining/external/ExternalLiquidityMining.sol";
import { BaseDelayedStrategy } from "../base/BaseDelayedStrategy.sol";
import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { ERC4626DelayedConnector } from "../../layers/connector/ERC4626DelayedConnector.sol";

contract ERC4626DelayedStrategy is
  BaseDelayedStrategy,
  ERC4626DelayedConnector,
  ExternalLiquidityMining,
  ExternalFees,
  ExternalTOSCreationValidation
{
  /// @inheritdoc IEarnStrategy
  string public description;

  // slither-disable-next-line naming-convention
  IDelayedWithdrawalAdapter internal immutable __delayedWithdrawalAdapter;
  IGlobalEarnRegistry internal immutable _globalRegistry;
  IEarnVault internal immutable _vault;
  address internal immutable _farmToken;

  constructor(
    // General
    IGlobalEarnRegistry globalRegistry_,
    IEarnVault vault_,
    address farmToken_,
    string memory description_,
    IDelayedWithdrawalAdapter delayedWithdrawalAdapter_
  ) {
    _globalRegistry = globalRegistry_;
    _vault = vault_;
    _farmToken = farmToken_;
    description = description_;
    __delayedWithdrawalAdapter = delayedWithdrawalAdapter_;
    maxApproveVault();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_underlying_asset() internal view override returns (address asset) {
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

  function _earnVault() internal view virtual override returns (IEarnVault) {
    return _vault;
  }

  function ERC4626Vault() public view virtual override returns (IERC4626) {
    return IERC4626(_farmToken);
  }

  function _asset() internal view virtual override returns (IERC20) {
    return IERC20(ERC4626Vault().asset());
  }

  function _delayedWithdrawalAdapter() internal view virtual override returns (IDelayedWithdrawalAdapter) {
    return __delayedWithdrawalAdapter;
  }
}
