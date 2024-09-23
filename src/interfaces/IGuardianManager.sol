// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { StrategyId, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

/// @notice Interface for the Guardian Manager that the strategies call
interface IGuardianManagerCore {
  /**
   * @notice Returns if the given account has permissions to start a rescue
   */
  function canStartRescue(StrategyId strategyId, address account) external view returns (bool);
  /**
   * @notice Returns if the given account has permissions to cancel a rescue
   */
  function canCancelRescue(StrategyId strategyId, address account) external view returns (bool);
  /**
   * @notice Returns if the given account has permissions to confirm a rescue
   */
  function canConfirmRescue(StrategyId strategyId, address account) external view returns (bool);

  /// @notice Allows the strategy to call the manager, for self-configuration
  function strategySelfConfigure(bytes calldata data) external;

  /**
   * @notice Alerts that a rescue has started
   * @dev May revert if the rescue is already in progress or if it has been confirmed already
   */
  function rescueStarted(StrategyId strategyId) external;
  /**
   * @notice Alerts that a rescue has been cancelled
   * @dev May revert if the rescue is not in progress
   */
  function rescueCancelled(StrategyId strategyId) external;
  /**
   * @notice Alerts that a rescue has been confirmed
   * @dev May revert if the rescue is not in progress
   */
  function rescueConfirmed(StrategyId strategyId) external;
}

interface IGuardianManager is IGuardianManagerCore {
  event GuardiansAssigned(StrategyId strategyId, address[] accounts);
  event GuardiansRemoved(StrategyId strategyId, address[] accounts);

  /**
   * @notice Returns the address of the strategy registry
   * @return The address of the strategy registry
   */
  // slither-disable-next-line naming-convention
  function STRATEGY_REGISTRY() external view returns (IEarnStrategyRegistry);

  /**
   * @notice Returns the global guardian role. Accounts with this role act as guardians for all strategies
   * @return The global guardian role
   */
  // slither-disable-next-line naming-convention
  function GLOBAL_GUARDIAN_ROLE() external view returns (bytes32);
  /**
   * @notice Returns the global judge role. Accounts with this role act as judges for all strategies
   * @return The global judge role
   */
  // slither-disable-next-line naming-convention
  function GLOBAL_JUDGE_ROLE() external view returns (bytes32);
  /**
   * @notice Returns the role in charge of managing guardians. Accounts with this role can assign and remove guardians
   * to individual strategies
   * @return The role in charge of managing guardians
   */
  // slither-disable-next-line naming-convention
  function MANAGE_GUARDIANS_ROLE() external view returns (bytes32);
  /**
   * @notice Returns the role in charge of managing judges. Accounts with this role can assign and remove judges to
   * individual strategies
   * @return The role in charge of managing judges
   */
  // slither-disable-next-line naming-convention
  function MANAGE_JUDGES_ROLE() external view returns (bytes32);

  /// @notice Returns if the given account is a guardian for the given strategy
  function isGuardian(StrategyId strategyId, address account) external view returns (bool);

  /// @notice Returns if the given account is a judge for the given strategy
  function isJudge(StrategyId strategyId, address account) external view returns (bool);

  /// @notice Assigns the given accounts as guardians for the given strategy
  function assignGuardians(StrategyId strategyId, address[] calldata guardians) external;

  /// @notice Removes the given accounts as guardians for the given strategy
  function removeGuardians(StrategyId strategyId, address[] calldata guardians) external;

  /// @notice Assigns the given accounts as judges for the given strategy
  function assignJudges(StrategyId strategyId, address[] calldata judges) external;

  /// @notice Removes the given accounts as judges for the given strategy
  function removeJudges(StrategyId strategyId, address[] calldata judges) external;
}
