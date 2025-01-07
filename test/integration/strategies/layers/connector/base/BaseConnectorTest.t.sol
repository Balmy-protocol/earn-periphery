// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import {
  IEarnStrategy,
  BaseConnector,
  SpecialWithdrawalCode,
  StrategyId
} from "src/strategies/layers/connector/base/BaseConnector.sol";
import { BaseConnectorInstance } from "./BaseConnectorInstance.sol";

abstract contract BaseConnectorTest is PRBTest, StdUtils, StdCheats {
  using SafeERC20 for IERC20;
  using Token for address;

  BaseConnectorInstance internal connector;

  function setUp() public {
    _configureFork();
    _setUp();
    connector = _buildNewConnector();
    vm.makePersistent(address(connector));
  }

  function testFork_allTokens() public {
    address[] memory tokens = connector.allTokens();
    assertGt(tokens.length, 0);
    assertEq(tokens[0], connector.asset());
  }

  function testFork_supportedDepositTokens() public {
    address[] memory depositTokens = connector.supportedDepositTokens();
    assertGt(depositTokens.length, 0);
    assertEq(depositTokens[0], connector.asset());
  }

  function testFork_maxDeposit() public {
    address[] memory depositTokens = connector.supportedDepositTokens();
    for (uint256 i; i < depositTokens.length; ++i) {
      assertGt(connector.maxDeposit(depositTokens[i]), 0);
    }
  }

  function testFork_maxDeposit_RevertWhen_InvalidToken() public {
    address token = address(1);
    vm.expectRevert(abi.encodeWithSelector(BaseConnector.InvalidDepositToken.selector, token));
    connector.maxDeposit(token);
  }

  function testFork_supportedWithdrawals() public {
    address[] memory tokens = connector.allTokens();
    assertEq(tokens.length, connector.supportedWithdrawals().length);
  }

  function testFork_maxWithdraw() public {
    _give(connector.asset(), address(this), 10e18);
    uint256 value = 0;
    if (connector.asset() == Token.NATIVE_TOKEN) {
      value = 10e18;
    } else {
      IERC20(connector.asset()).forceApprove(address(connector), 10e18);
    }
    connector.deposit{ value: value }(connector.asset(), 10e18);

    (address[] memory tokens, uint256[] memory withdrawable) = connector.maxWithdraw();
    (address[] memory balanceTokens, uint256[] memory balances) = connector.totalBalances();

    assertEq(tokens.length, withdrawable.length);

    // Make sure tokens are valid
    assertEq(tokens, balanceTokens);

    // Make sure amounts are consistent
    for (uint256 i; i < withdrawable.length; i++) {
      assertLte(withdrawable[i], balances[i]);
    }
  }

  function testFork_specialWithdraw_RevertWhen_InvalidCode() public {
    SpecialWithdrawalCode code = SpecialWithdrawalCode.wrap(type(uint256).max);
    vm.expectRevert(abi.encodeWithSelector(BaseConnector.InvalidSpecialWithdrawalCode.selector, code));
    connector.specialWithdraw(1, code, new uint256[](0), "", address(this));
  }

  function testFork_totalBalances() public {
    address[] memory tokens = connector.allTokens();
    (address[] memory balanceTokens, uint256[] memory balances) = connector.totalBalances();

    assertEq(tokens, balanceTokens);
    assertEq(balanceTokens.length, balances.length);
  }

  function testFork_deposit() public {
    address[] memory supported = connector.supportedDepositTokens();
    for (uint256 i; i < supported.length; ++i) {
      (, uint256[] memory balancesBefore) = connector.totalBalances();
      address depositToken = supported[i];
      _give(depositToken, address(this), 10e10);
      uint256 value = 0;
      if (depositToken == Token.NATIVE_TOKEN) {
        value = 10e10;
      } else {
        IERC20(depositToken).forceApprove(address(connector), type(uint256).max);
      }
      // Note: some rebasing tokens might provide a little less than expected, so we need to make this check
      uint256 toDeposit = Math.min(depositToken.balanceOf(address(this)), 10e10);
      uint256 assetsDeposited = connector.deposit{ value: value }(depositToken, toDeposit);
      (, uint256[] memory balancesAfter) = connector.totalBalances();
      assertAlmostEq(assetsDeposited, balancesAfter[0] - balancesBefore[0], 1);
    }
  }

  function testFork_deposit_RevertWhen_InvalidToken() public {
    address token = address(1);
    vm.expectRevert(abi.encodeWithSelector(BaseConnector.InvalidDepositToken.selector, token));
    connector.deposit(token, 1e18);
  }

  function testFork_migrateToNewStrategy() public {
    _give(connector.asset(), address(this), 10e18);
    uint256 value = 0;
    if (connector.asset() == Token.NATIVE_TOKEN) {
      value = 10e18;
    } else {
      IERC20(connector.asset()).forceApprove(address(connector), 10e18);
    }
    connector.deposit{ value: value }(connector.asset(), 10e18);

    // Generate yield if connector handles it
    _generateYield();

    BaseConnectorInstance newConnector = _buildNewConnector();

    (, uint256[] memory oldConnectorBalancesBefore) = connector.totalBalances();
    (, uint256[] memory newConnectorBalancesBefore) = newConnector.totalBalances();

    // Migrate
    connector.migrateToNewStrategy(IEarnStrategy(address(newConnector)), "");

    // Make sure balances were migrated correctly
    (, uint256[] memory oldConnectorBalancesAfter) = connector.totalBalances();
    (, uint256[] memory newConnectorBalancesAfter) = newConnector.totalBalances();

    for (uint256 i; i < oldConnectorBalancesAfter.length; ++i) {
      // Allow for some loss due to rebasing tokens transfers
      assertAlmostEq(newConnectorBalancesAfter[i] - newConnectorBalancesBefore[i], oldConnectorBalancesBefore[i], 2);
      assertAlmostEq(oldConnectorBalancesAfter[i], 0, 2);
    }
  }

  function testFork_strategyRegistered_emptyMigrationData() public {
    // Note: we just make sure it can be called without it reverting
    connector.strategyRegistered(StrategyId.wrap(1), IEarnStrategy(address(0)), "");
  }

  function _setUp() internal virtual;

  function _configureFork() internal virtual;

  function _buildNewConnector() internal virtual returns (BaseConnectorInstance);

  function _balance(address asset, address account) internal view returns (uint256) {
    return asset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE ? account.balance : IERC20(asset).balanceOf(account);
  }

  function _setBalance(address asset, address account, uint256 amount) internal virtual {
    if (asset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      deal(account, amount);
    } else {
      deal(asset, account, amount);
    }
  }

  function _give(address asset, address account, uint256 amount) internal returns (uint256 newBalance) {
    uint256 balance = _balance(asset, account);
    _setBalance(asset, account, balance + amount);
    return balance + amount;
  }

  // solhint-disable no-empty-blocks
  function _generateYield() internal virtual { }
}
