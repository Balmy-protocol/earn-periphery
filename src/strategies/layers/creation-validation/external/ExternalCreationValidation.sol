// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { ICreationValidationManagerCore, StrategyId } from "src/interfaces/ICreationValidationManager.sol";
import { BaseCreationValidation } from "../base/BaseCreationValidation.sol";

abstract contract ExternalCreationValidation is BaseCreationValidation, Initializable {
  /// @notice The id for the Creation Validation Manager
  bytes32 public constant CREATION_VALIDATION_MANAGER = keccak256("CREATION_VALIDATION_MANAGER");

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

  // slither-disable-next-line naming-convention,dead-code
  function _creationValidation_init(bytes calldata data) internal onlyInitializing {
    _getCreationValidationManager().strategySelfConfigure(data);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _creationValidation_validate(address toValidate, bytes calldata data) internal override {
    _getCreationValidationManager().validatePositionCreation(strategyId(), toValidate, msg.sender, data);
  }

  // slither-disable-next-line dead-code
  function _getCreationValidationManager() private view returns (ICreationValidationManagerCore) {
    return ICreationValidationManagerCore(globalRegistry().getAddressOrFail(CREATION_VALIDATION_MANAGER));
  }
}
