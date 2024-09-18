// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IEarnStrategy, SpecialWithdrawalCode, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IGlobalEarnRegistry } from "../../interfaces/IGlobalEarnRegistry.sol";
import { IGuardianManagerCore } from "../../interfaces/IGuardianManager.sol";
import { BaseGuardian } from "./base/BaseGuardian.sol";

/**
 * @notice A guardian implementation that validates the rescue process with an external manager
 * @dev It's important to note that this implementation will only work when all tokens support immediate withdrawals.
 *      A rescue with delayed withdrawals will revert
 */
abstract contract ExternalGuardian is BaseGuardian, Initializable {
  /// @notice The id for the Guardian Manager
  bytes32 public constant GUARDIAN_MANAGER = keccak256("GUARDIAN_MANAGER");

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

  /**
   * @notice Starts a rescue process for this strategy. When a rescue is started, we will try to withdraw all funds from
   * the underlying source.
   *         It could happen that not all funds can be withdrawn when the rescue is executed, so this function can be
   * called multiple times.
   *         Each time, all possible funds will be withdrawn into the strategy
   * @dev Even though the function can be called multiple times, the recipient set on the first call will be the one
   * that receives the rescue fee.
   *      This function can only be called by accounts that have the permission to do so
   * @param feeRecipient The recipient of the rescue fee.
   * @return tokens Tokens what were rescued
   * @return rescued Amount that was rescued for each token
   */
  function rescue(address feeRecipient) external returns (address[] memory tokens, uint256[] memory rescued) { }

  /**
   * @notice Cancels a rescue process that was started. All withdrawn funds will be re-deposited into the underlying
   * source.
   * @dev This function can only be called by accounts that have the permission to do so
   */
  function cancelRescue() external { }

  /**
   * @notice Confirms a rescue process that was started. When this happens, the rescue fee will be charged and the
   * rescue process will be completed.
   *         This means that `rescue` cannot be called anymore
   * @dev This function can only be called by accounts that have the permission to do so
   */
  function confirmRescue() external { }

  // slither-disable-next-line naming-convention
  function _guardian_underlying_tokens() internal view virtual returns (address[] memory tokens);

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_init(bytes calldata data) internal onlyInitializing {
    IGuardianManagerCore manager = _getGuardianManager();
    manager.strategySelfConfigure(data);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  { }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  { }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_withdraw(
    uint256 positionId,
    address[] calldata tokens,
    uint256[] calldata toWithdraw,
    address recipient
  )
    internal
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  { }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  { }

  // slither-disable-next-line dead-code
  function _getGuardianManager() private view returns (IGuardianManagerCore) {
    return IGuardianManagerCore(globalRegistry().getAddressOrFail(GUARDIAN_MANAGER));
  }
}
