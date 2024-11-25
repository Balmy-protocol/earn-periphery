// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import {
  BaseConnector,
  IEarnStrategy,
  SpecialWithdrawalCode,
  IDelayedWithdrawalAdapter,
  StrategyId
} from "src/strategies/layers/connector/base/BaseConnector.sol";

abstract contract BaseConnectorInstance is BaseConnector {
  function asset() external view returns (address) {
    return _connector_asset();
  }

  function allTokens() external view returns (address[] memory tokens) {
    return _connector_allTokens();
  }

  function isDepositTokenSupported(address depositToken) external view returns (bool) {
    return _connector_isDepositTokenSupported(depositToken);
  }

  function supportedDepositTokens() external view returns (address[] memory supported) {
    return _connector_supportedDepositTokens();
  }

  function maxDeposit(address depositToken) external view returns (uint256) {
    return _connector_maxDeposit(depositToken);
  }

  function supportedWithdrawals() external view returns (IEarnStrategy.WithdrawalType[] memory) {
    return _connector_supportedWithdrawals();
  }

  function isSpecialWithdrawalSupported(SpecialWithdrawalCode withdrawalCode) external view returns (bool) {
    return _connector_isSpecialWithdrawalSupported(withdrawalCode);
  }

  function supportedSpecialWithdrawals() external view returns (SpecialWithdrawalCode[] memory codes) {
    return _connector_supportedSpecialWithdrawals();
  }

  function maxWithdraw() external view returns (address[] memory tokens, uint256[] memory withdrawable) {
    return _connector_maxWithdraw();
  }

  function totalBalances() external view returns (address[] memory tokens, uint256[] memory balances) {
    return _connector_totalBalances();
  }

  function delayedWithdrawalAdapter(address token) external view returns (IDelayedWithdrawalAdapter) {
    return _connector_delayedWithdrawalAdapter(token);
  }

  function deposit(address depositToken, uint256 depositAmount) external returns (uint256 assetsDeposited) {
    return _connector_deposit(depositToken, depositAmount);
  }

  function withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    external
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return _connector_withdraw(positionId, tokens, toWithdraw, recipient);
  }

  function specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    external
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    return _connector_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
  }

  function migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    external
    returns (bytes memory)
  {
    return _connector_migrateToNewStrategy(newStrategy, migrationData);
  }

  function strategyRegistered(StrategyId strategyId, IEarnStrategy oldStrategy, bytes calldata migrationData) external {
    return _connector_strategyRegistered(strategyId, oldStrategy, migrationData);
  }
}
