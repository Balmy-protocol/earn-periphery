// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { IEarnStrategyRegistry, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { ICreationValidationManagerCore } from "src/interfaces/ICreationValidationManager.sol";

/**
 * @notice This manager allows admins to define signers for strategies. When a
 *         signer is set for a strategy (or group), then positions can only be
 *         created for that strategy if the signer has signed a message explicitly
 */
interface ISignatureBasedWhitelistManager is ICreationValidationManagerCore {
  /// @notice Thrown when an invalid signature is provided
  error InvalidSignature(bytes signature);

  /// @notice Thrown when the deadline is missed
  error MissedDeadline(uint256 deadline, uint256 currentTimestamp);

  /// @notice Thrown when the caller is not authorized to perform the action
  error UnauthorizedCaller();

  /// @notice Emitted when the signer for a group is updated
  event SignerUpdated(bytes32 group, address signer);

  /// @notice Emitted when a strategy is assigned to a group
  event StrategyAssignedToGroup(StrategyId strategyId, bytes32 group);

  /// @notice Returns the role given to accounts that are allowed to skip validation
  // slither-disable-next-line naming-convention
  function NO_VALIDATION_ROLE() external view returns (bytes32);

  /// @notice Returns the role given to accounts that "spend" a nonce when validating
  // slither-disable-next-line naming-convention
  function NONCE_SPENDER_ROLE() external view returns (bytes32);

  /// @notice Returns the role given to accounts that are allowed to update the signer for a group
  // slither-disable-next-line naming-convention
  function MANAGE_SIGNERS_ROLE() external view returns (bytes32);

  /// @notice Returns the typehash for the validation signature
  // slither-disable-next-line naming-convention
  function VALIDATION_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the address of the strategy registry
  // slither-disable-next-line naming-convention
  function STRATEGY_REGISTRY() external view returns (IEarnStrategyRegistry);

  /**
   * @notice Returns the nonce for a strategy and account
   * @param strategyId The strategy id
   * @param account The account
   * @return The nonce
   */
  function getNonce(StrategyId strategyId, address account) external view returns (uint256);

  /**
   * @notice Returns the group for a strategy
   * @param strategyId The strategy id
   * @return The group
   */
  function getStrategyGroup(StrategyId strategyId) external view returns (bytes32);

  /**
   * @notice Returns the signer for a group
   * @dev If the returned signer is the zero address, then all accounts are allowed to skip validation
   *      for all strategies in this group
   * @param group The group
   * @return The signer
   */
  function getGroupSigner(bytes32 group) external view returns (address);

  /**
   * @notice Returns the signer for a strategy
   * @dev If the returned signer is the zero address, then all accounts are allowed to skip validation
   *      If the strategy is not assigned to a group, then we'll return the zero address
   * @param strategyId The strategy id
   * @return The signer
   */
  function getStrategySigner(StrategyId strategyId) external view returns (address);

  /**
   * @notice Updates the signer for a group
   * @param group The group
   * @param signer The signer
   */
  function updateSigner(bytes32 group, address signer) external;

  /**
   * @notice Assigns a strategy to a group
   * @param strategyId The strategy id
   * @param group The group
   */
  function assignStrategyToGroup(StrategyId strategyId, bytes32 group) external;
}
