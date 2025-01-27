// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IEarnStrategy, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { IFeeManagerCore, StrategyId, Fees } from "src/interfaces/IFeeManager.sol";
import { BaseFees } from "../base/BaseFees.sol";

/// @dev This fees layer implementation only supports performance fees
abstract contract ExternalFees is BaseFees, ReentrancyGuard, Initializable {
  error CantWithdrawFees();
  error NotEnoughFees();
  error WithdrawMustBeImmediate();
  error InvalidTokens();

  struct PerformanceData {
    uint128 lastBalance;
    uint120 performanceFees;
    bool isSet;
  }

  using SafeCast for uint256;

  /// @notice The id for the Fee Manager
  bytes32 public constant FEE_MANAGER = keccak256("FEE_MANAGER");

  mapping(address token => PerformanceData data) private _performanceData;

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

  /// @notice Returns the amount of collected fees
  function collectedFees() public view returns (address[] memory tokens, uint256[] memory collected) {
    Fees memory fees = _getFees();
    uint256[] memory balances;
    (tokens, balances) = _fees_underlying_totalBalances();
    collected = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; ++i) {
      collected[i] = _calculateFees(tokens[i], balances[i], fees.performanceFee);
    }
  }

  function withdrawFees(address[] calldata tokens, uint256[] calldata toWithdraw, address recipient) external {
    Fees memory fees = _getFeesOrFailIfSenderCantWithdraw();
    (address[] memory allTokens, uint256[] memory currentBalances) = _fees_underlying_totalBalances();
    _updateFeesForWithdraw({ tokens: tokens, withdrawAmounts: toWithdraw, currentBalances: currentBalances, fees: fees });
    _fees_underlying_withdraw(0, tokens, toWithdraw, recipient);
    if (tokens.length != allTokens.length) {
      revert InvalidTokens();
    }
    IEarnStrategy.WithdrawalType[] memory types = _fees_underlying_supportedWithdrawals();
    for (uint256 i; i < tokens.length; ++i) {
      if (allTokens[i] != tokens[i]) {
        revert InvalidTokens();
      }
      if (toWithdraw[i] > 0 && types[i] != IEarnStrategy.WithdrawalType.IMMEDIATE) {
        revert WithdrawMustBeImmediate();
      }
    }
  }

  function specialWithdrawFees(
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    external
    nonReentrant
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    Fees memory fees = _getFeesOrFailIfSenderCantWithdraw();
    (address[] memory tokens, uint256[] memory currentBalances) = _fees_underlying_totalBalances();

    (balanceChanges, actualWithdrawnTokens, actualWithdrawnAmounts, result) =
      _fees_underlying_specialWithdraw(0, withdrawalCode, toWithdraw, withdrawData, recipient);

    _updateFeesForWithdraw({
      tokens: tokens,
      withdrawAmounts: balanceChanges,
      currentBalances: currentBalances,
      fees: fees
    });
  }

  // slither-disable-next-line naming-convention
  function _fees_underlying_asset() internal view virtual returns (address asset);

  // slither-disable-next-line naming-convention,dead-code
  function _fees_init(bytes calldata data) internal onlyInitializing {
    IFeeManagerCore feeManager = _getFeeManager();
    feeManager.strategySelfConfigure(data);
  }

  // slither-disable-next-line naming-convention,dead-code,assembly
  function _fees_fees() internal view override returns (IEarnStrategy.FeeType[] memory types, uint16[] memory bps) {
    Fees memory fees = _getFees();
    types = new IEarnStrategy.FeeType[](4);
    bps = new uint16[](4);
    uint256 count = 0;
    count = addFeeToArrays(types, bps, fees.depositFee, IEarnStrategy.FeeType.DEPOSIT, count);
    count = addFeeToArrays(types, bps, fees.withdrawFee, IEarnStrategy.FeeType.WITHDRAW, count);
    count = addFeeToArrays(types, bps, fees.rescueFee, IEarnStrategy.FeeType.RESCUE, count);
    count = addFeeToArrays(types, bps, fees.performanceFee, IEarnStrategy.FeeType.PERFORMANCE, count);

    // solhint-disable-next-line no-inline-assembly
    assembly {
      mstore(types, count)
      mstore(bps, count)
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_totalBalances() internal view override returns (address[] memory tokens, uint256[] memory balances) {
    Fees memory fees = _getFees();
    (tokens, balances) = _fees_underlying_totalBalances();
    for (uint256 i; i < tokens.length; ++i) {
      uint256 balance = balances[i];
      balances[i] = balance - _calculateFees(tokens[i], balance, fees.performanceFee);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  {
    Fees memory fees = _getFees();
    if (fees.performanceFee == 0) {
      // If performance fee is 0, we will need to clear the last balance. Otherwise, once it's turned on again,
      // we won't be able to understand difference between balance changes and yield
      _clearBalanceIfSet(_fees_underlying_asset());
      return _fees_underlying_deposit(depositToken, depositAmount);
    }

    // Note: we are only updating fees for the asset, since it's the only token whose balance will change
    (address[] memory tokens, uint256[] memory currentBalances) = _fees_underlying_totalBalances();
    address asset = tokens[0];
    uint256 currentBalanceAsset = currentBalances[0];
    uint256 performanceFees = _calculateFees(asset, currentBalanceAsset, fees.performanceFee);

    assetsDeposited = _fees_underlying_deposit(depositToken, depositAmount);

    _storePerformanceData({
      token: asset,
      // Note: there might be a small wei difference here, but we can ignore it since it should be negligible
      lastBalance: (currentBalanceAsset + assetsDeposited),
      performanceFees: performanceFees,
      isSet: true
    });
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    override
  {
    Fees memory fees = _getFees();
    if (fees.performanceFee == 0) {
      _clearAllBalancesIfSet(tokens);
      _fees_underlying_withdraw(positionId, tokens, toWithdraw, recipient);
    }

    (, uint256[] memory currentBalances) = _fees_underlying_totalBalances();
    for (uint256 i; i < tokens.length; ++i) {
      uint256 amountToWithdraw = toWithdraw[i];
      // If there is nothing being withdrawn, we can skip fee update, since balance didn't change
      if (amountToWithdraw == 0) continue;
      address token = tokens[i];
      uint256 currentBalance = currentBalances[i];
      uint256 performanceFees = _calculateFees(token, currentBalance, fees.performanceFee);
      _storePerformanceData({
        token: token,
        // Note: there might be a small wei difference here, but we can ignore it an avoid adding it as part of the fee
        lastBalance: (currentBalance - amountToWithdraw),
        performanceFees: performanceFees,
        isSet: true
      });
    }

    _fees_underlying_withdraw(positionId, tokens, toWithdraw, recipient);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_specialWithdraw(
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
    Fees memory fees = _getFees();
    if (fees.performanceFee == 0) {
      address[] memory allTokens = _fees_underlying_tokens();
      _clearAllBalancesIfSet(allTokens);
      return _fees_underlying_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
    }

    (address[] memory tokens, uint256[] memory currentBalances) = _fees_underlying_totalBalances();

    (balanceChanges, actualWithdrawnTokens, actualWithdrawnAmounts, result) =
      _fees_underlying_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);

    for (uint256 i; i < tokens.length; ++i) {
      address token = tokens[i];
      uint256 currentBalance = currentBalances[i];
      _storePerformanceData({
        token: token,
        // Note: there might be a small wei difference here, but we can ignore it an avoid adding it as part of the fee
        lastBalance: (currentBalance - balanceChanges[i]),
        performanceFees: _calculateFees(token, currentBalance, fees.performanceFee),
        isSet: true
      });
    }
  }

  function _fees_strategyRegistered(
    StrategyId strategyId_,
    IEarnStrategy oldStrategy,
    bytes calldata migrationResultData
  )
    internal
    override
  {
    // Note: when a strategy is registered, we will calculate the current balance and store it. The thing is that any
    // performance fees that were held by a previous strategy would be lost. We don't migrate this data because of the
    // contract size constraint, so the fees should be claimed before the migration is executed
    Fees memory fees = _getFees();
    if (fees.performanceFee > 0) {
      (address[] memory tokens, uint256[] memory currentBalances) = _fees_underlying_totalBalances();
      for (uint256 i; i < tokens.length; ++i) {
        _storePerformanceData({ token: tokens[i], lastBalance: currentBalances[i], performanceFees: 0, isSet: true });
      }
    }
    _fees_underlying_strategyRegistered(strategyId_, oldStrategy, migrationResultData);
  }

  // slither-disable-next-line dead-code
  function _getFees() internal view returns (Fees memory fees) {
    return _getFeeManager().getFees(strategyId());
  }

  // slither-disable-next-line dead-code
  function _clearAllBalancesIfSet(address[] memory tokens) private {
    for (uint256 i; i < tokens.length; ++i) {
      _clearBalanceIfSet(tokens[i]);
    }
  }

  // slither-disable-next-line dead-code
  function _clearBalanceIfSet(address token) private {
    PerformanceData memory tokenPerfData = _performanceData[token];
    if (tokenPerfData.isSet) {
      _storePerformanceData({
        token: token,
        lastBalance: 0,
        performanceFees: tokenPerfData.performanceFees,
        isSet: false
      });
    }
  }

  // slither-disable-next-line dead-code
  function _calculateFees(address token, uint256 currentBalance, uint256 performanceFee) private view returns (uint256) {
    PerformanceData memory perfData = _performanceData[token];
    if (perfData.isSet && currentBalance > perfData.lastBalance) {
      uint256 yield = currentBalance - perfData.lastBalance;
      uint256 fee = (yield * performanceFee) / 10_000;
      return Math.min(fee + perfData.performanceFees, currentBalance);
    }
    return Math.min(perfData.performanceFees, currentBalance);
  }

  // slither-disable-next-line dead-code
  function _getFeeManager() private view returns (IFeeManagerCore) {
    return IFeeManagerCore(globalRegistry().getAddressOrFail(FEE_MANAGER));
  }

  // slither-disable-next-line dead-code
  function _getFeesOrFailIfSenderCantWithdraw() private view returns (Fees memory) {
    StrategyId strategyId_ = strategyId();
    IFeeManagerCore feeManager = _getFeeManager();
    if (!feeManager.canWithdrawFees(strategyId_, msg.sender)) {
      revert CantWithdrawFees();
    }
    return feeManager.getFees(strategyId_);
  }

  // slither-disable-next-line dead-code
  function _updateFeesForWithdraw(
    address[] memory tokens,
    uint256[] memory withdrawAmounts,
    uint256[] memory currentBalances,
    Fees memory fees
  )
    private
  {
    for (uint256 i = 0; i < tokens.length; ++i) {
      address token = tokens[i];
      uint256 currentBalance = currentBalances[i];
      uint256 amountToWithdraw = withdrawAmounts[i];
      if (amountToWithdraw > 0) {
        uint256 collected = _calculateFees(token, currentBalance, fees.performanceFee);
        if (amountToWithdraw > collected) {
          revert NotEnoughFees();
        }

        if (fees.performanceFee > 0) {
          _storePerformanceData({
            token: token,
            // Note: there might be a small wei difference here, but we can ignore it since it should be negligible
            lastBalance: (currentBalance - amountToWithdraw),
            performanceFees: (collected - amountToWithdraw),
            isSet: true
          });
        } else {
          _storePerformanceData({
            token: token,
            lastBalance: 0,
            performanceFees: (collected - amountToWithdraw),
            isSet: false
          });
        }
      }
    }
  }

  function _storePerformanceData(address token, uint256 lastBalance, uint256 performanceFees, bool isSet) private {
    _performanceData[token] = PerformanceData({
      lastBalance: lastBalance.toUint128(),
      performanceFees: performanceFees.toUint120(),
      isSet: isSet
    });
  }

  function addFeeToArrays(
    IEarnStrategy.FeeType[] memory types,
    uint16[] memory bps,
    uint16 fee,
    IEarnStrategy.FeeType feeType,
    uint256 count
  )
    internal
    pure
    returns (uint256)
  {
    if (fee == 0) return count;
    types[count] = feeType;
    bps[count++] = fee;
    return count;
  }
}
