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

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  /// @notice The id assigned to this strategy
  function strategyId() public view virtual returns (StrategyId);

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
  { }

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
  function _getFees() private view returns (Fees memory fees) {
    return _getFeeManager().getFees(strategyId());
  }

  // slither-disable-next-line dead-code
  function _getFeeManager() private view returns (IFeeManager) {
    return IFeeManager(globalRegistry().getAddressOrFail(FEE_MANAGER));
  }
}
