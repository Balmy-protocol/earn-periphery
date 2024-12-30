// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {
  IValidationManagersRegistry,
  IValidationManagersRegistryCore,
  ICreationValidationManagerCore,
  StrategyId
} from "src/interfaces/IValidationManagersRegistry.sol";

/// @notice This registry will use the same list of managers for all strategies
contract GlobalValidationManagersRegistry is IValidationManagersRegistry, Ownable2Step {
  ICreationValidationManagerCore[] private _managers;

  constructor(ICreationValidationManagerCore[] memory managers, address owner_) Ownable(owner_) {
    _managers = managers;
    emit ManagersSet(managers);
  }

  /// @inheritdoc IValidationManagersRegistryCore
  function getManagers(StrategyId) external view returns (ICreationValidationManagerCore[] memory) {
    return _managers;
  }

  /// @inheritdoc IValidationManagersRegistryCore
  function strategySelfConfigure(bytes calldata) external view returns (ICreationValidationManagerCore[] memory) {
    return _managers;
  }

  /// @inheritdoc IValidationManagersRegistry
  function setManagers(ICreationValidationManagerCore[] memory managers) external onlyOwner {
    _managers = managers;
    emit ManagersSet(managers);
  }
}
