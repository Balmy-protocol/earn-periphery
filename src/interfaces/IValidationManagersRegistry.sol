// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { ICreationValidationManagerCore } from "./ICreationValidationManager.sol";

interface IValidationManagersRegistryCore {
  /**
   * @notice Allows the strategy to call the registry, for self-configuration
   */
  function strategySelfConfigure(bytes calldata data) external;

  /**
   * @notice Returns the list of registered managers for the given strategy
   * @param strategyId The id of the strategy
   * @return The managers
   */
  function getManagers(StrategyId strategyId) external view returns (ICreationValidationManagerCore[] memory);
}

interface IValidationManagersRegistry is IValidationManagersRegistryCore {
  /**
   * @notice Emitted when the managers are set
   * @param managers The manager addresses
   */
  event ManagersSet(ICreationValidationManagerCore[] managers);

  /**
   * @notice Sets the managers for all strategies
   * @param managers The managers
   */
  function setManagers(ICreationValidationManagerCore[] memory managers) external;
}
