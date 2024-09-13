// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IEarnStrategy, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IGlobalEarnRegistry } from "../../interfaces/IGlobalEarnRegistry.sol";
import { IFeeManager, StrategyId, Fees } from "../../interfaces/IFeeManager.sol";
import { BaseFees } from "./base/BaseFees.sol";

abstract contract ExternalFees is BaseFees, Initializable {
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
    for (uint256 i = 0; i < tokens.length; i++) {
      collected[i] = _calculateFees(tokens[i], balances[i], fees.performanceFee);
    }
  }

  // slither-disable-next-line naming-convention
  function _fees_underlying_asset() internal view virtual returns (address asset);

  // slither-disable-next-line naming-convention,dead-code,assembly
  function _fees_fees() internal view override returns (IEarnStrategy.FeeType[] memory types, uint16[] memory bps) {
    Fees memory fees = _getFees();
    types = new IEarnStrategy.FeeType[](4);
    bps = new uint16[](4);
    uint256 count = 0;
    if (fees.depositFee > 0) {
      types[count] = IEarnStrategy.FeeType.DEPOSIT;
      bps[count++] = fees.depositFee;
    }
    if (fees.withdrawFee > 0) {
      types[count] = IEarnStrategy.FeeType.WITHDRAW;
      bps[count++] = fees.withdrawFee;
    }
    if (fees.performanceFee > 0) {
      types[count] = IEarnStrategy.FeeType.PERFORMANCE;
      bps[count++] = fees.performanceFee;
    }
    if (fees.rescueFee > 0) {
      types[count] = IEarnStrategy.FeeType.RESCUE;
      bps[count++] = fees.rescueFee;
    }

    // solhint-disable-next-line no-inline-assembly
    assembly {
      mstore(types, count)
      mstore(bps, count)
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_totalBalances() internal view override returns (address[] memory tokens, uint256[] memory balances) { }

  // slither-disable-next-line naming-convention,dead-code
  function _fees_deposited(
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
      address asset = _fees_underlying_asset();
      _clearBalanceIfSet(asset);
      return _fees_underlying_deposited(depositToken, depositAmount);
    }

    // Note: we are only updating fees for the asset, since it's the only token whose balance will change
    (address[] memory tokens, uint256[] memory currentBalances) = _fees_underlying_totalBalances();
    uint256 performanceFees = _calculateFees(tokens[0], currentBalances[0], fees.performanceFee);

    assetsDeposited = _fees_underlying_deposited(depositToken, depositAmount);

    _performanceData[tokens[0]] = PerformanceData({
      // Note: there might be a small wei difference here, but we can ignore it since it should be negligible
      lastBalance: (currentBalances[0] + assetsDeposited).toUint128(),
      performanceFees: performanceFees.toUint120(),
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
    returns (IEarnStrategy.WithdrawalType[] memory types)
  { }

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
  { }

  // slither-disable-next-line dead-code
  function _clearBalanceIfSet(address token) private {
    PerformanceData memory tokenPerfData = _performanceData[token];
    if (tokenPerfData.isSet) {
      _performanceData[token] =
        PerformanceData({ lastBalance: 0, isSet: false, performanceFees: tokenPerfData.performanceFees });
    }
  }

  // slither-disable-next-line dead-code
  function _calculateFees(address token, uint256 currentBalance, uint256 performanceFee) private view returns (uint256) {
    PerformanceData memory perfData = _performanceData[token];
    if (perfData.isSet && currentBalance > perfData.lastBalance) {
      uint256 yield = currentBalance - perfData.lastBalance;
      uint256 fee = (yield * performanceFee) / 10_000;
      return fee + perfData.performanceFees;
    }
    return perfData.performanceFees;
  }

  // slither-disable-next-line dead-code
  function _getFees() private view returns (Fees memory fees) {
    return _getFeeManager().getFees(strategyId());
  }

  // slither-disable-next-line dead-code
  function _getFeeManager() private view returns (IFeeManager) {
    return IFeeManager(globalRegistry().getAddressOrFail(FEE_MANAGER));
  }
}
