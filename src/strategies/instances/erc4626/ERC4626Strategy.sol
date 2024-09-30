// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IEarnStrategy, StrategyId, IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Clone } from "@clones/Clone.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { ERC4626Connector } from "../../layers/connector/ERC4626Connector.sol";
import { ExternalFees } from "../../layers/fees/ExternalFees.sol";
import { ExternalGuardian } from "../../layers/guardian/ExternalGuardian.sol";
import { ExternalTOSCreationValidation } from "../../layers/creation-validation/ExternalTOSCreationValidation.sol";
import { BaseStrategy } from "../base/BaseStrategy.sol";

contract ERC4626Strategy is
  BaseStrategy,
  Clone,
  ERC4626Connector,
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
    override(ExternalFees, ExternalGuardian, ExternalTOSCreationValidation, BaseStrategy)
    returns (StrategyId)
  {
    return BaseStrategy.strategyId();
  }

  // Immutable params:
  // 1. Earn Vault (20B)
  // 2. Global Registry (20B)
  // 3. ERC4626 vault (20B)
  // 4. Asset (20B)

  function _earnVault() internal pure override returns (IEarnVault) {
    return IEarnVault(_getArgAddress(0));
  }

  function globalRegistry()
    public
    pure
    override(ExternalFees, ExternalGuardian, ExternalTOSCreationValidation)
    returns (IGlobalEarnRegistry)
  {
    return IGlobalEarnRegistry(_getArgAddress(20));
  }

  // slither-disable-next-line naming-convention
  function ERC4626Vault() public pure override returns (IERC4626) {
    return IERC4626(_getArgAddress(40));
  }

  function _asset() internal pure override returns (IERC20) {
    return IERC20(_getArgAddress(60));
  }

  // slither-disable-next-line naming-convention
  function _fees_underlying_asset() internal view override returns (address asset) {
    return _connector_asset();
  }

  // slither-disable-next-line naming-convention
  function _guardian_rescueFee() internal view override returns (uint16) {
    return _getFees().rescueFee;
  }
}
