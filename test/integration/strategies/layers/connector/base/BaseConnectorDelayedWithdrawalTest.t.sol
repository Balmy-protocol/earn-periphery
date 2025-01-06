// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseConnectorTest, IEarnStrategy } from "./BaseConnectorTest.t.sol";
import { IDelayedWithdrawalAdapter } from "src/interfaces/IDelayedWithdrawalAdapter.sol";

/// @notice A test for connectors that have delayed withdrawals
abstract contract BaseConnectorDelayedWithdrawalTest is BaseConnectorTest {
  function testFork_delayedWithdrawalAdapter_delayedWithdrawal() public {
    address[] memory tokens = connector.allTokens();
    IEarnStrategy.WithdrawalType[] memory supported = connector.supportedWithdrawals();
    for (uint256 i; i < tokens.length; ++i) {
      if (IEarnStrategy.WithdrawalType.DELAYED == supported[i]) {
        assertNotEq(address(0), address(connector.delayedWithdrawalAdapter(tokens[i])));
      }
    }
  }

  function testFork_supportedWithdrawals_delayedWithdrawal_atLeastOneDelayed() public {
    IEarnStrategy.WithdrawalType[] memory supported = connector.supportedWithdrawals();
    uint256 delayedCount;
    for (uint256 i; i < supported.length; ++i) {
      if (IEarnStrategy.WithdrawalType.DELAYED == supported[i]) {
        delayedCount++;
      }
    }
    assertGte(delayedCount, 1);
  }

  function testFork_withdraw_initiateDelayedWithdrawal() public {
    // Deposit tokens
    _give(connector.asset(), address(connector), 10e18);
    connector.deposit(connector.asset(), 10e18);

    // Generate yield if connector handles it
    _generateYield();

    // Check previous state
    address[] memory tokens = connector.allTokens();
    (, uint256[] memory balancesBefore) = connector.totalBalances();

    // Withdraw
    uint256[] memory toWithdraw = new uint256[](tokens.length);
    IDelayedWithdrawalAdapter[] memory adapters = new IDelayedWithdrawalAdapter[](tokens.length);
    for (uint256 i; i < tokens.length; ++i) {
      toWithdraw[i] = balancesBefore[i] / 2;
      adapters[i] = connector.delayedWithdrawalAdapter(tokens[i]);
    }

    connector.withdraw(0, tokens, toWithdraw, address(1));

    // Check remaining balances
    (, uint256[] memory balancesAfter) = connector.totalBalances();
    for (uint256 i; i < tokens.length; ++i) {
      assertAlmostEq(adapters[i].estimatedPendingFunds(0, tokens[i]), toWithdraw[i], 1);
      assertAlmostEq(toWithdraw[i], balancesBefore[i] - balancesAfter[i], 1);
    }
  }
}
