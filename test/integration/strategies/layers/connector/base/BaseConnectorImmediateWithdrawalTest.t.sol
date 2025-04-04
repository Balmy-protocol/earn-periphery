// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseConnectorTest, IEarnStrategy, SafeERC20, IERC20, Token } from "./BaseConnectorTest.t.sol";

/// @notice A test for connectors that have immediate withdrawals

abstract contract BaseConnectorImmediateWithdrawalTest is BaseConnectorTest {
  using SafeERC20 for IERC20;

  function testFork_delayedWithdrawalAdapter_immediateWithdrawal() public {
    address[] memory tokens = connector.allTokens();
    for (uint256 i; i < tokens.length; ++i) {
      assertEq(address(0), address(connector.delayedWithdrawalAdapter(tokens[i])));
    }
  }

  function testFork_supportedWithdrawals_immediateWithdrawal_allImmediate() public {
    IEarnStrategy.WithdrawalType[] memory supported = connector.supportedWithdrawals();
    for (uint256 i; i < supported.length; ++i) {
      assertTrue(IEarnStrategy.WithdrawalType.IMMEDIATE == supported[i]);
    }
  }

  function testFork_withdraw_immediateWithdrawal() public {
    // Set recipient to 0
    address recipient = address(0xea4);

    // Deposit tokens
    _give(connector.asset(), address(this), 10e12);
    uint256 value = 0;
    if (connector.asset() == Token.NATIVE_TOKEN) {
      value = 10e12;
    } else {
      IERC20(connector.asset()).forceApprove(address(connector), 10e12);
    }
    connector.deposit{ value: value }(connector.asset(), 10e12);

    // Generate yield if connector handles it
    _generateYield();

    // Check previous state
    address[] memory tokens = connector.allTokens();
    (, uint256[] memory balancesBefore) = connector.totalBalances();

    // Withdraw
    uint256[] memory toWithdraw = new uint256[](tokens.length);
    for (uint256 i; i < tokens.length; ++i) {
      toWithdraw[i] = balancesBefore[i] / 2;
    }

    uint256[] memory recipientBalancesBefore = new uint256[](tokens.length);
    for (uint256 i; i < tokens.length; ++i) {
      recipientBalancesBefore[i] = _balance(tokens[i], recipient);
    }
    connector.withdraw(1, tokens, toWithdraw, recipient);

    // Check remaining balances
    (, uint256[] memory balancesAfter) = connector.totalBalances();
    for (uint256 i; i < tokens.length; ++i) {
      assertAlmostEq(_balance(tokens[i], recipient) - recipientBalancesBefore[i], toWithdraw[i], 1);
      // Note: We use a delta of 1 because of rounding errors
      if (toWithdraw[i] > 0) {
        assertGte(balancesAfter[i] + 1, balancesBefore[i] - toWithdraw[i]);
      }
    }
  }
}
