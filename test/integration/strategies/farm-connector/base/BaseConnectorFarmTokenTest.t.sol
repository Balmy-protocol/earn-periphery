// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";
import { BaseConnectorTest, IEarnStrategy, SpecialWithdrawalCode } from "./BaseConnectorTest.t.sol";

/// @notice A test for connector that have use a farm token directly
abstract contract BaseConnectorFarmTokenTest is BaseConnectorTest {
  using ArrayHelper for SpecialWithdrawalCode[];
  using ArrayHelper for address[];

  function testFork_supportedDepositTokens_farmToken() public {
    address[] memory supported = connector.supportedDepositTokens();
    assertTrue(supported.contains(_farmToken()));
  }

  function testFork_maxDeposit_farmToken() public {
    assertEq(connector.maxDeposit(_farmToken()), type(uint256).max);
  }

  function testFork_supportedSpecialWithdrawals_farmToken() public {
    SpecialWithdrawalCode[] memory codes = connector.supportedSpecialWithdrawals();
    assertTrue(codes.contains(SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT));
    assertTrue(codes.contains(SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT));
  }

  function testFork_specialWithdraw_farmToken_withdrawFarmTokenFarByAmount() public {
    address recipient = address(1);
    uint256 originalConnectorBalance = 10e18;
    uint256 amountToWithdraw = 2e18;
    _setBalance(_farmToken(), recipient, 0);
    _setBalance(_farmToken(), address(connector), originalConnectorBalance);

    (, uint256[] memory balancesBefore) = connector.totalBalances();

    (uint256[] memory withdrawn, IEarnStrategy.WithdrawalType[] memory withdrawalTypes, bytes memory withdrawData) =
    connector.specialWithdraw(
      1, SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT, abi.encode(amountToWithdraw), recipient
    );

    (, uint256[] memory balancesAfter) = connector.totalBalances();

    // Check assets
    uint256 assetsWithdrawn = abi.decode(withdrawData, (uint256));
    assertEq(withdrawn.length, balancesBefore.length);
    assertEq(withdrawn[0], assetsWithdrawn);
    assertAlmostEq(assetsWithdrawn, balancesBefore[0] - balancesAfter[0], 1);

    // Check withdrawal type
    assertEq(withdrawalTypes.length, 1);
    assertTrue(withdrawalTypes[0] == IEarnStrategy.WithdrawalType.IMMEDIATE);

    // Check transfer
    assertAlmostEq(_balance(_farmToken(), recipient), amountToWithdraw, 1);
    assertAlmostEq(_balance(_farmToken(), address(connector)), originalConnectorBalance - amountToWithdraw, 1);
  }

  function testFork_specialWithdraw_farmToken_withdrawFarmTokenByAssetAmount() public {
    address recipient = address(1);
    uint256 originalConnectorBalance = 10e18;
    uint256 assetsToWithdraw = 2e18;
    _setBalance(_farmToken(), recipient, 0);
    _setBalance(_farmToken(), address(connector), originalConnectorBalance);

    (, uint256[] memory balancesBefore) = connector.totalBalances();

    (uint256[] memory withdrawn, IEarnStrategy.WithdrawalType[] memory withdrawalTypes, bytes memory withdrawData) =
    connector.specialWithdraw(
      1, SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT, abi.encode(assetsToWithdraw), recipient
    );

    (, uint256[] memory balancesAfter) = connector.totalBalances();

    // Check assets
    assertEq(withdrawn.length, balancesBefore.length);
    assertEq(withdrawn[0], assetsToWithdraw);
    assertAlmostEq(assetsToWithdraw, balancesBefore[0] - balancesAfter[0], 1);

    // Check withdrawal type
    assertEq(withdrawalTypes.length, 1);
    assertTrue(withdrawalTypes[0] == IEarnStrategy.WithdrawalType.IMMEDIATE);

    // Check transfer
    uint256 sharesWithdrawn = abi.decode(withdrawData, (uint256));
    assertAlmostEq(_balance(_farmToken(), recipient), sharesWithdrawn, 1);
    assertAlmostEq(_balance(_farmToken(), address(connector)), originalConnectorBalance - sharesWithdrawn, 1);
  }

  function _farmToken() internal view virtual returns (address);
}

library ArrayHelper {
  function contains(SpecialWithdrawalCode[] memory codes, SpecialWithdrawalCode code) internal pure returns (bool) {
    for (uint256 i; i < codes.length; ++i) {
      if (codes[i] == code) {
        return true;
      }
    }
    return false;
  }

  function contains(address[] memory addresses, address toFind) internal pure returns (bool) {
    for (uint256 i; i < addresses.length; ++i) {
      if (addresses[i] == toFind) {
        return true;
      }
    }
    return false;
  }
}
