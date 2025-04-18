// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IEarnStrategy, SpecialWithdrawalCode, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { IGuardianManagerCore } from "src/interfaces/IGuardianManager.sol";
import { BaseGuardian } from "../base/BaseGuardian.sol";

/**
 * @notice A guardian implementation that validates the rescue process with an external manager
 * @dev It's important to note that this implementation will only work when all tokens support immediate withdrawals.
 *      A rescue with delayed withdrawals will revert
 *      Another important aspect to note is that this layer withdraws all funds when trying to rescue them. But it keeps
 *      them in the strategy's contract until the rescue is either confirmed or cancelled. If the rescue is cancelled,
 *      then all assets are re-deposited, but rescued rewards are left on the strategy's contract. This implementation
 *      assumes that the underlying layer will consider these rewards as part of the balance, and will know how to
 *      handle them during a withdrawal
 */
abstract contract ExternalGuardian is BaseGuardian, Initializable {
  enum RescueStatus {
    OK,
    RESCUE_NEEDS_CONFIRMATION,
    RESCUED
  }

  struct RescueConfig {
    uint16 feeBps;
    address feeRecipient;
    RescueStatus status;
  }

  error InvalidRescueStatus();
  error CallerCantPerformAction();
  error OnlyImmediateWithdrawalsSupported();

  using Token for address;
  using Math for uint256;

  /// @notice The id for the Guardian Manager
  bytes32 public constant GUARDIAN_MANAGER = keccak256("GUARDIAN_MANAGER");

  /// @notice Returns the strategy's current config
  RescueConfig public rescueConfig;

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

  /**
   * @notice Starts a rescue process for this strategy. When a rescue is started, we will try to withdraw all funds from
   *         the underlying source. It could happen that not all funds can be withdrawn when the rescue is executed, so
   *         this function can be called multiple times. Each time, all possible funds will be withdrawn into the
   *         strategy
   * @dev Even though the function can be called multiple times, the recipient set on the first call will be the one
   *      that receives the rescue fee. This function can only be called by accounts that have the permission to do so
   * @param feeRecipient The recipient of the rescue fee.
   * @return tokens Tokens what were rescued
   * @return rescued Amount that was rescued for each token
   */
  function rescue(address feeRecipient) external returns (address[] memory tokens, uint256[] memory rescued) {
    RescueStatus status = rescueConfig.status;
    if (status == RescueStatus.RESCUED) {
      revert InvalidRescueStatus();
    }

    StrategyId strategyId_ = strategyId();
    IGuardianManagerCore manager = _getGuardianManager();
    if (!manager.canStartRescue(strategyId_, msg.sender)) {
      revert CallerCantPerformAction();
    }

    if (status != RescueStatus.RESCUE_NEEDS_CONFIRMATION) {
      // If we weren't waiting for confirmation before, then set correct config and alert manager
      rescueConfig = RescueConfig({
        feeRecipient: feeRecipient,
        feeBps: _guardian_rescueFee(),
        status: RescueStatus.RESCUE_NEEDS_CONFIRMATION
      });
      manager.rescueStarted(strategyId_);
    }

    (tokens, rescued) = _guardian_underlying_maxWithdraw();
    _guardian_underlying_withdraw(0, tokens, rescued, address(this));
    IEarnStrategy.WithdrawalType[] memory types = _guardian_underlying_supportedWithdrawals();
    if (!_areAllImmediate(types)) {
      revert OnlyImmediateWithdrawalsSupported();
    }
  }

  /**
   * @notice Cancels a rescue process that was started. All withdrawn funds will be re-deposited into the underlying
   *         source.
   * @dev This function can only be called by accounts that have the permission to do so
   */
  function cancelRescue() external {
    _assertRescueStatus(RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    StrategyId strategyId_ = strategyId();
    IGuardianManagerCore manager = _getGuardianManager();
    if (!manager.canCancelRescue(strategyId_, msg.sender)) {
      revert CallerCantPerformAction();
    }

    address[] memory tokens = _guardian_underlying_tokens();
    uint256 assetBalance = tokens[0].balanceOf(address(this));

    if (assetBalance > 0) {
      // Since funds are already on the contract, there is no need to take them from the caller
      _guardian_underlying_deposit({ depositToken: tokens[0], depositAmount: assetBalance, takeFromCaller: false });
    }

    rescueConfig = RescueConfig({ feeBps: 0, feeRecipient: address(0), status: RescueStatus.OK });

    manager.rescueCancelled(strategyId_);
  }

  /**
   * @notice Confirms a rescue process that was started. When this happens, the rescue fee will be charged and the
   *         rescue process will be completed. This means that `rescue` cannot be called anymore
   * @dev This function can only be called by accounts that have the permission to do so
   */
  function confirmRescue() external {
    RescueConfig memory rescueConfig_ = rescueConfig;
    if (rescueConfig_.status != RescueStatus.RESCUE_NEEDS_CONFIRMATION) {
      revert InvalidRescueStatus();
    }

    StrategyId strategyId_ = strategyId();
    IGuardianManagerCore manager = _getGuardianManager();
    if (!manager.canConfirmRescue(strategyId_, msg.sender)) {
      revert CallerCantPerformAction();
    }

    rescueConfig.status = RescueStatus.RESCUED;
    manager.rescueConfirmed(strategyId_);
    address[] memory tokens = _guardian_underlying_tokens();
    for (uint256 i = 0; i < tokens.length; ++i) {
      address token = tokens[i];
      uint256 balance = token.balanceOf(address(this));
      uint256 fee = balance.mulDiv(rescueConfig_.feeBps, 10_000, Math.Rounding.Floor);
      token.transfer(rescueConfig_.feeRecipient, fee);
    }
  }

  // slither-disable-next-line naming-convention
  function _guardian_rescueFee() internal view virtual returns (uint16);

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_init(bytes calldata data) internal onlyInitializing {
    rescueConfig = RescueConfig({ feeBps: 0, feeRecipient: address(0), status: RescueStatus.OK });
    IGuardianManagerCore manager = _getGuardianManager();
    manager.strategySelfConfigure(data);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    RescueStatus status = rescueConfig.status;
    if (status == RescueStatus.OK) {
      return _guardian_underlying_totalBalances();
    } else if (status == RescueStatus.RESCUE_NEEDS_CONFIRMATION) {
      (tokens, balances) = _guardian_underlying_totalBalances();
      // We might have withdrawn some of the assets, so we add that to the balance. Also, like we explained before, we
      // assume that the underlying layer will consider the rewards on the contract as part of the balance
      balances[0] += tokens[0].balanceOf(address(this));
    } else {
      tokens = _guardian_underlying_tokens();
      balances = new uint256[](tokens.length);
      for (uint256 i = 0; i < tokens.length; ++i) {
        balances[i] = tokens[i].balanceOf(address(this));
      }
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  {
    _assertOkRescueStatus();
    return
      _guardian_underlying_deposit({ depositToken: depositToken, depositAmount: depositAmount, takeFromCaller: true });
  }

  // slither-disable-start naming-convention,dead-code
  // solhint-disable-next-line code-complexity
  function _guardian_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    override
  {
    RescueStatus status = rescueConfig.status;
    if (status == RescueStatus.OK) {
      // In this case, we just withdraw from the underlying layer
      return _guardian_underlying_withdraw(positionId, tokens, toWithdraw, recipient);
    } else if (status == RescueStatus.RESCUED) {
      // If we are in "rescued" mode, then we simply transfer balance on the strategy
      for (uint256 i = 0; i < tokens.length; ++i) {
        tokens[i].transfer(recipient, toWithdraw[i]);
      }
    } else {
      // If we get here, we are waiting for confirmation, so we can't withdraw
      revert InvalidRescueStatus();
    }
  }
  // slither-disable-end naming-convention,dead-code

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
  {
    // Note: even though the contract might have reward balance, special withdrawals are very particular and depend on
    //       the underlying implementation. So we won't use this balance in this case
    _assertOkRescueStatus();
    return _guardian_underlying_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _guardian_migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    internal
    override
    returns (bytes memory)
  {
    _assertOkRescueStatus();
    return _guardian_underlying_migrateToNewStrategy(newStrategy, migrationData);
  }

  // slither-disable-next-line dead-code
  function _getGuardianManager() private view returns (IGuardianManagerCore) {
    return IGuardianManagerCore(globalRegistry().getAddressOrFail(GUARDIAN_MANAGER));
  }

  function _assertOkRescueStatus() private view {
    _assertRescueStatus(RescueStatus.OK);
  }

  function _assertRescueStatus(RescueStatus status) private view {
    if (rescueConfig.status != status) {
      revert InvalidRescueStatus();
    }
  }

  function _areAllImmediate(IEarnStrategy.WithdrawalType[] memory types) private pure returns (bool) {
    for (uint256 i; i < types.length; ++i) {
      if (types[i] != IEarnStrategy.WithdrawalType.IMMEDIATE) {
        return false;
      }
    }
    return true;
  }
}
