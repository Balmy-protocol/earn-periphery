// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { ITOSManagerCore, StrategyId } from "../../../interfaces/ITOSManager.sol";
import { BaseCreationValidation } from "./base/BaseCreationValidation.sol";

abstract contract ExternalTOSCreationValidation is BaseCreationValidation, Initializable {
  /// @notice The id for the TOS Manager
  bytes32 public constant TOS_MANAGER = keccak256("TOS_MANAGER");

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

  // slither-disable-next-line naming-convention,dead-code
  function _creationValidation_init(bytes calldata data) internal onlyInitializing {
    _getTOSManager().strategySelfConfigure(data);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _creationValidation_validate(address sender, bytes calldata signature) internal view override {
    _getTOSManager().validatePositionCreation(strategyId(), sender, signature);
  }

  // slither-disable-next-line dead-code
  function _getTOSManager() private view returns (ITOSManagerCore) {
    return ITOSManagerCore(globalRegistry().getAddressOrFail(TOS_MANAGER));
  }
}
