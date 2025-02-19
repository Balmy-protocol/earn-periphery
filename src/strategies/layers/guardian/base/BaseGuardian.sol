// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

/**
 * @notice The base layer for guardian implementations
 * @dev Ideally we would also overwrite other strategy functions like `maxDeposit` and `maxWithdraw`, but we want to
 *      keep the contract as small as possible and those are not as relevant as the currently overwritten functions
 */
abstract contract BaseGuardian {
  // slither-disable-start naming-convention
  /// Underlying
  function _guardian_underlying_tokens() internal view virtual returns (address[] memory tokens);
  function _guardian_underlying_maxWithdraw()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory withdrawable);
  function _guardian_underlying_totalBalances()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory balances);
  function _guardian_underlying_deposit(
    address depositToken,
    uint256 depositAmount,
    bool takeFromCaller
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
    virtual;
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
  function _guardian_underlying_supportedWithdrawals()
    internal
    view
    virtual
    returns (IEarnStrategy.WithdrawalType[] memory);
  function _guardian_underlying_migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    internal
    virtual
    returns (bytes memory);

  // Guardian
  function _guardian_totalBalances() internal view virtual returns (address[] memory tokens, uint256[] memory balances);
  function _guardian_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    returns (uint256 assetsDeposited);
  function _guardian_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    virtual;
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
  function _guardian_migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    internal
    virtual
    returns (bytes memory);
  // slither-disable-end naming-convention
}
