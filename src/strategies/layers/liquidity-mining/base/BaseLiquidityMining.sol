// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnStrategy, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

abstract contract BaseLiquidityMining {
  // slither-disable-start naming-convention
  /// Underlying
  function _liquidity_mining_underlying_allTokens() internal view virtual returns (address[] memory tokens);
  function _liquidity_mining_underlying_maxWithdraw()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory withdrawable);
  function _liquidity_mining_underlying_totalBalances()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory balances);
  function _liquidity_mining_underlying_supportedWithdrawals()
    internal
    view
    virtual
    returns (IEarnStrategy.WithdrawalType[] memory);
  function _liquidity_mining_underlying_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    returns (uint256 assetsDeposited);
  function _liquidity_mining_underlying_specialWithdraw(
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

  // liquidity_mining
  function _liquidity_mining_allTokens() internal view virtual returns (address[] memory tokens);
  function _liquidity_mining_totalBalances()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory balances);
  function _liquidity_mining_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    returns (uint256 assetsDeposited);
  function _liquidity_mining_withdraw(
    uint256 positionId,
    address[] calldata tokens,
    uint256[] calldata toWithdraw,
    address recipient
  )
    internal
    virtual
    returns (IEarnStrategy.WithdrawalType[] memory types);
  function _liquidity_mining_specialWithdraw(
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
  function _liquidity_mining_supportedWithdrawals()
    internal
    view
    virtual
    returns (IEarnStrategy.WithdrawalType[] memory);
  function _liquidity_mining_maxWithdraw()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory withdrawable);
  // slither-disable-end naming-convention
}
