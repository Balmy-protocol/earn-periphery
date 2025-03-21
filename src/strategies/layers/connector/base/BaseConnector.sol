// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { StrategyId, IEarnStrategy, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

import { IDelayedWithdrawalAdapter } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";

abstract contract BaseConnector {
  error InvalidDepositToken(address invalidToken);
  error InvalidSpecialWithdrawalCode(SpecialWithdrawalCode invalidCode);

  // slither-disable-start naming-convention
  function _connector_asset() internal view virtual returns (address);

  function _connector_allTokens() internal view virtual returns (address[] memory tokens);
  function _connector_supportedDepositTokens() internal view virtual returns (address[] memory supported);
  function _connector_maxDeposit(address depositToken) internal view virtual returns (uint256);
  function _connector_supportedWithdrawals() internal view virtual returns (IEarnStrategy.WithdrawalType[] memory);
  function _connector_supportedSpecialWithdrawals()
    internal
    view
    virtual
    returns (SpecialWithdrawalCode[] memory codes);
  function _connector_maxWithdraw()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory withdrawable);
  function _connector_totalBalances()
    internal
    view
    virtual
    returns (address[] memory tokens, uint256[] memory balances);
  function _connector_delayedWithdrawalAdapter(address token) internal view virtual returns (IDelayedWithdrawalAdapter);
  function _connector_deposit(
    address depositToken,
    uint256 depositAmount,
    bool takeFromCaller
  )
    internal
    virtual
    returns (uint256 assetsDeposited);
  function _connector_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    virtual;
  function _connector_specialWithdraw(
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
  function _connector_migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    internal
    virtual
    returns (bytes memory);
  function _connector_strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationData
  )
    internal
    virtual;
  // slither-disable-end naming-convention
}
