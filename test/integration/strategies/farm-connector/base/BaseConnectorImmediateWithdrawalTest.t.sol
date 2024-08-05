// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseConnectorTest, IEarnStrategy } from "./BaseConnectorTest.t.sol";

/// @notice A test for connectors that have immediate withdrawals
abstract contract BaseConnectorImmediateWithdrawalTest is BaseConnectorTest {
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
    address recipient = address(1);
    _setBalance(connector.asset(), recipient, 0);

    // Deposit tokens
    _give(connector.asset(), address(connector), 10e18);
    connector.deposit(connector.asset(), 10e18);

    // Check previous state
    address[] memory tokens = connector.allTokens();
    (, uint256[] memory balancesBefore) = connector.totalBalances();

    // Withdraw
    uint256[] memory toWithdraw = new uint256[](tokens.length);
    toWithdraw[0] = balancesBefore[0] / 2;
    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = connector.withdraw(1, tokens, toWithdraw, address(1));

    // Check result
    assertEq(withdrawalTypes.length, tokens.length);
    for (uint256 i; i < withdrawalTypes.length; ++i) {
      assertTrue(withdrawalTypes[i] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    }

    // Check remaining balances
    (, uint256[] memory balancesAfter) = connector.totalBalances();
    assertAlmostEq(_balance(connector.asset(), recipient), toWithdraw[0], 1);
    assertAlmostEq(toWithdraw[0], balancesBefore[0] - balancesAfter[0], 1);
  }
}
