// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";
import { BaseConnectorTest, SpecialWithdrawalCode } from "./BaseConnectorTest.t.sol";

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

  function testFork_specialWithdraw_farmToken_withdrawFarmTokenByAmount() public {
    address recipient = address(1);
    uint256 originalConnectorBalance = _connectorBalanceOfFarmToken();
    uint256 amountToWithdraw = _amountToWithdrawFarmToken();
    uint256[] memory toWithdraw = new uint256[](1);
    toWithdraw[0] = amountToWithdraw;
    _setBalance(_farmToken(), recipient, 0);
    _setBalance(_farmToken(), address(connector), originalConnectorBalance);

    (, uint256[] memory balancesBefore) = connector.totalBalances();

    (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    ) = connector.specialWithdraw(1, SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT, toWithdraw, "", recipient);

    (, uint256[] memory balancesAfter) = connector.totalBalances();

    // Check assets
    uint256 assetsWithdrawn = balanceChanges[0];
    assertEq(balanceChanges.length, balancesBefore.length);
    assertAlmostEq(assetsWithdrawn, balancesBefore[0] - balancesAfter[0], 1);

    // Check actual tokens and amounts
    assertEq(actualWithdrawnTokens.length, 1);
    assertEq(actualWithdrawnAmounts.length, 1);
    assertEq(actualWithdrawnTokens[0], _farmToken());
    assertEq(actualWithdrawnAmounts[0], amountToWithdraw);

    // Check result
    assertTrue(result.length == 0);

    // Check transfer
    assertAlmostEq(_balance(_farmToken(), recipient), amountToWithdraw, 1);
    assertAlmostEq(_balance(_farmToken(), address(connector)), originalConnectorBalance - amountToWithdraw, 1);
  }

  function testFork_specialWithdraw_farmToken_withdrawFarmTokenByAssetAmount() public {
    address recipient = address(1);
    uint256 originalConnectorBalance = _connectorBalanceOfFarmToken();
    uint256 assetsToWithdraw = _amountToWithdrawAsset();
    uint256[] memory toWithdraw = new uint256[](1);
    toWithdraw[0] = assetsToWithdraw;
    _setBalance(_farmToken(), recipient, 0);
    _setBalance(_farmToken(), address(connector), originalConnectorBalance);

    (, uint256[] memory balancesBefore) = connector.totalBalances();

    (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    ) = connector.specialWithdraw(
      1, SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT, toWithdraw, "", recipient
    );

    (, uint256[] memory balancesAfter) = connector.totalBalances();

    // Check assets
    uint256 assetsWithdrawn = balanceChanges[0];
    assertEq(balanceChanges.length, balancesBefore.length);
    assertAlmostEq(assetsWithdrawn, balancesBefore[0] - balancesAfter[0], 1);
    assertAlmostEq(assetsToWithdraw, assetsWithdrawn, _withdrawFarmTokenByAssetMaxDelta());

    // Check actual tokens and amounts
    assertEq(actualWithdrawnTokens.length, 1);
    assertEq(actualWithdrawnAmounts.length, 1);
    assertEq(actualWithdrawnTokens[0], _farmToken());

    // Check result
    assertTrue(result.length == 0);

    // Check transfer
    uint256 sharesWithdrawn = actualWithdrawnAmounts[0];
    assertAlmostEq(_balance(_farmToken(), recipient), sharesWithdrawn, 1);
    assertAlmostEq(_balance(_farmToken(), address(connector)), originalConnectorBalance - sharesWithdrawn, 1);
  }

  function _farmToken() internal view virtual returns (address);

  function _connectorBalanceOfFarmToken() internal pure virtual returns (uint256) {
    return 10e18;
  }

  function _withdrawFarmTokenByAssetMaxDelta() internal pure virtual returns (uint256) {
    return 1;
  }

  function _amountToWithdrawAsset() internal pure virtual returns (uint256) {
    return 2e18;
  }

  function _amountToWithdrawFarmToken() internal pure virtual returns (uint256) {
    return 2e18;
  }
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
