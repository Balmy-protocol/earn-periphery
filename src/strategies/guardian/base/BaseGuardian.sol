// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { IEarnStrategy, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

/**
 * @notice The base layer for guardian implementations
 * @dev Ideally we would also overwrite other strategy functions like `maxDeposit` and `maxWithdraw`, but we want to
 *      keep the contract as small as possible and those are not as relevant as the currently overwriten functions
 */
abstract contract BaseGuardian {
  // slither-disable-start naming-convention
  /// Underlying
  function _guardian_underlying_maxWithdraw()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory withdrawable);
  function _guardian_underlying_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    returns (uint256 assetsDeposited);
  function _guardian_underlying_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    virtual
    returns (IEarnStrategy.WithdrawalType[] memory);
  function _guardian_underlying_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    virtual
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    );

  // Guardian
  function _guardian_totalBalances() internal view virtual returns (address[] memory tokens, uint256[] memory balances);
  function _guardian_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    returns (uint256 assetsDeposited);
  function _guardian_withdraw(
    uint256 positionId,
    address[] calldata tokens,
    uint256[] calldata toWithdraw,
    address recipient
  )
    internal
    virtual
    returns (IEarnStrategy.WithdrawalType[] memory types);
  function _guardian_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    virtual
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    );
  // slither-disable-end naming-convention
}
