// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, SpecialWithdrawalCode, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

abstract contract BaseFees {
  // slither-disable-start naming-convention

  /// Underlying
  function _fees_underlying_tokens() internal view virtual returns (address[] memory tokens);
  function _fees_underlying_totalBalances()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory balances);
  function _fees_underlying_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    returns (uint256 assetsDeposited);
  function _fees_underlying_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    virtual;
  function _fees_underlying_specialWithdraw(
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

  function _fees_underlying_supportedWithdrawals()
    internal
    view
    virtual
    returns (IEarnStrategy.WithdrawalType[] memory);

  function _fees_underlying_strategyRegistered(
    StrategyId strategyId_,
    IEarnStrategy oldStrategy,
    bytes calldata migrationResultData
  )
    internal
    virtual;

  // Fees
  function _fees_fees() internal view virtual returns (IEarnStrategy.FeeType[] memory types, uint16[] memory bps);
  function _fees_totalBalances() internal view virtual returns (address[] memory tokens, uint256[] memory balances);

  function _fees_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    returns (uint256 assetsDeposited);

  function _fees_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    virtual;

  function _fees_specialWithdraw(
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
  function _fees_strategyRegistered(
    StrategyId strategyId_,
    IEarnStrategy oldStrategy,
    bytes calldata migrationResultData
  )
    internal
    virtual;
  // slither-disable-end naming-convention
}
