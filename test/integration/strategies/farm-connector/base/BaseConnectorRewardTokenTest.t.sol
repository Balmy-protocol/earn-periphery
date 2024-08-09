// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseConnectorFarmTokenTest, IEarnStrategy } from "./BaseConnectorFarmTokenTest.t.sol";

/// @notice A test for connector that
abstract contract BaseConnectorRewardTokenTest is BaseConnectorFarmTokenTest {
  using ArrayHelper for address[];

  function testFork_withdraw_immediateWithdrawal_rewardTokens() public {
    // Set recipient to 0
    address recipient = address(1);
    _setBalance(_farmToken(), recipient, 0);

    address[] memory rewardTokens = _rewardTokens();

    // Deposit tokens
    _give(_farmToken(), address(connector), 10e18);
    connector.deposit(_farmToken(), 10e18);

    vm.rollFork(123_000_000); // Roll the fork to generate some rewards

    (address[] memory tokens, uint256[] memory balancesBefore) = connector.totalBalances();

    uint256[] memory toWithdraw = new uint256[](tokens.length);

    for (uint256 i; i < rewardTokens.length; ++i) {
      // Remove reward tokens from recipient, only to avoid to save previous rewards balance
      _setBalance(rewardTokens[i], recipient, 0);

      // Withdraw
      toWithdraw[i + 1] = balancesBefore[i + 1] / 2;
    }

    IEarnStrategy.WithdrawalType[] memory withdrawalTypes = connector.withdraw(1, tokens, toWithdraw, recipient);

    for (uint256 i; i < rewardTokens.length; ++i) {
      address rewardToken = rewardTokens[i];

      // Check result
      assertTrue(withdrawalTypes[i + 1] == IEarnStrategy.WithdrawalType.IMMEDIATE);

      // Check remaining balances
      (, uint256[] memory balancesAfter) = connector.totalBalances();
      assertEq(_balance(rewardToken, recipient), toWithdraw[i + 1]);
      assertAlmostEq(toWithdraw[i + 1], balancesBefore[i + 1] - balancesAfter[i + 1], 1);
    }
  }

  function _rewardTokens() internal view virtual returns (address[] memory);
}

library ArrayHelper {
  function contains(address[] memory addresses, address toFind) internal pure returns (bool) {
    for (uint256 i; i < addresses.length; ++i) {
      if (addresses[i] == toFind) {
        return true;
      }
    }
    return false;
  }
}
