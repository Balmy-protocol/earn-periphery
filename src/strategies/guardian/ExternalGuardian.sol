// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IEarnStrategy, SpecialWithdrawalCode, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { IGlobalEarnRegistry } from "../../interfaces/IGlobalEarnRegistry.sol";
import { IGuardianManagerCore } from "../../interfaces/IGuardianManager.sol";
import { StrategyHelper } from "../libraries/StrategyHelper.sol";
import { BaseGuardian } from "./base/BaseGuardian.sol";

/**
 * @notice A guardian implementation that validates the rescue process with an external manager
 * @dev It's important to note that this implementation will only work when all tokens support immediate withdrawals.
 *      A rescue with delayed withdrawals will revert
 */
abstract contract ExternalGuardian is BaseGuardian, Initializable {
  enum RescueStatus {
    OK,
    OK_WITH_BALANCE_ON_STRATEGY,
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
    IEarnStrategy.WithdrawalType[] memory types = _guardian_underlying_withdraw(0, tokens, rescued, address(this));
    if (!StrategyHelper.areAllImmediate(types)) {
      revert OnlyImmediateWithdrawalsSupported();
    }
  }

  /**
   * @notice Cancels a rescue process that was started. All withdrawn funds will be re-deposited into the underlying
   *         source.
   * @dev This function can only be called by accounts that have the permission to do so
   */
  function cancelRescue() external {
    if (rescueConfig.status != RescueStatus.RESCUE_NEEDS_CONFIRMATION) {
      revert InvalidRescueStatus();
    }

    StrategyId strategyId_ = strategyId();
    IGuardianManagerCore manager = _getGuardianManager();
    if (!manager.canCancelRescue(strategyId_, msg.sender)) {
      revert CallerCantPerformAction();
    }

    address[] memory tokens = _guardian_underlying_tokens();
    uint256 assetBalance = tokens[0].balanceOf(address(this));
    _guardian_underlying_deposited(tokens[0], assetBalance);

    rescueConfig = RescueConfig({
      feeBps: 0,
      feeRecipient: address(0),
      status: _isThereRewardBalanceOnContract(tokens) ? RescueStatus.OK_WITH_BALANCE_ON_STRATEGY : RescueStatus.OK
    });

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
    for (uint256 i = 0; i < tokens.length; ++i {
      uint256 balance = tokens[i].balanceOf(address(this));
      uint256 fee = balance.mulDiv(rescueConfig_.feeBps, 10_000, Math.Rounding.Floor);
      tokens[i].transfer(rescueConfig_.feeRecipient, fee);
    }
  }

  // slither-disable-next-line naming-convention
  function _guardian_underlying_tokens() internal view virtual returns (address[] memory tokens);

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
    } else if (status == RescueStatus.OK_WITH_BALANCE_ON_STRATEGY || status == RescueStatus.RESCUE_NEEDS_CONFIRMATION) {
      (tokens, balances) = _guardian_underlying_totalBalances();
      for (uint256 i = 0; i < tokens.length; ++i) {
        balances[i] += tokens[i].balanceOf(address(this));
      }
    } else {
      tokens = _guardian_underlying_tokens();
      balances = new uint256[](tokens.length);
      for (uint256 i = 0; i < tokens.length; ++i) {
        balances[i] = tokens[i].balanceOf(address(this));
      }
    }
  }

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

  function _isThereRewardBalanceOnContract(address[] memory tokens) private view returns (bool) {
    for (uint256 i = 1; i < tokens.length; ++i {
      uint256 balance = tokens[i].balanceOf(address(this));
      if (balance > 0) {
        return true;
      }
    }
    return false;
  }
}
