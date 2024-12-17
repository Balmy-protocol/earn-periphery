// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { ICreationValidationManagerCore, StrategyId } from "src/interfaces/ICreationValidationManager.sol";
import { IValidationManagersRegistryCore } from "src/interfaces/IValidationManagersRegistry.sol";
import { BaseCreationValidation } from "../base/BaseCreationValidation.sol";

abstract contract RegistryBasedCreationValidation is BaseCreationValidation, Initializable {
  error InvalidData();

  /// @notice The id for the Validation Managers Registry
  bytes32 public constant VALIDATION_MANAGERS_REGISTRY = keccak256("VALIDATION_MANAGERS_REGISTRY");

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

  // slither-disable-next-line naming-convention,dead-code
  function _creationValidation_init(bytes calldata data) internal onlyInitializing {
    (bytes memory registryData, bytes[] memory managersData) = abi.decode(data, (bytes, bytes[]));

    IValidationManagersRegistryCore registry = _getRegistry();
    registry.strategySelfConfigure(registryData);

    ICreationValidationManagerCore[] memory managers = registry.getManagers(strategyId());
    if (managersData.length != managers.length) {
      revert InvalidData();
    }

    for (uint256 i = 0; i < managers.length; ++i) {
      managers[i].strategySelfConfigure(managersData[i]);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _creationValidation_validate(address toValidate, bytes calldata data) internal override {
    bytes[] memory dataArray = _decodeData(data);
    StrategyId strategyId_ = strategyId();
    IValidationManagersRegistryCore registry = _getRegistry();
    ICreationValidationManagerCore[] memory managers = registry.getManagers(strategyId_);

    if (dataArray.length != managers.length) {
      revert InvalidData();
    }

    for (uint256 i = 0; i < managers.length; ++i) {
      managers[i].validatePositionCreation(strategyId_, toValidate, msg.sender, dataArray[i]);
    }
  }

  // slither-disable-next-line dead-code
  function _decodeData(bytes calldata data) private pure returns (bytes[] memory dataArray) {
    return data.length > 0 ? abi.decode(data, (bytes[])) : new bytes[](0);
  }

  // slither-disable-next-line dead-code
  function _getRegistry() private view returns (IValidationManagersRegistryCore) {
    return IValidationManagersRegistryCore(globalRegistry().getAddressOrFail(VALIDATION_MANAGERS_REGISTRY));
  }
}
