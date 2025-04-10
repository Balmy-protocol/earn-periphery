// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseStrategyTest } from "./BaseStrategyTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseLiquidityMiningTest is BaseStrategyTest {
  function testFuzzFork_campaign_withdraw(uint80 depositAmount, uint80 withdrawAmount, uint24 rewardAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (, uint256[] memory previousBalances,,) = vault.position(positionId);

    _setLMCampaign(rewardAmount);

    _warpTime(rewardAmount / 2);

    vm.startPrank(owner);
    (address[] memory tokens, uint256[] memory balances,,) = vault.position(positionId);

    assertEq(previousBalances.length + 1, balances.length, "Balances length is not correct");

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0] / 2));
    uint256 rewardAmountToWithdraw = balances[tokens.length - 1];
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount;
    intendedWithdraw[tokens.length - 1] = rewardAmountToWithdraw;
    uint256 rewardBalance = _balance(lmmToken);
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    assertAlmostEq(_balance(lmmToken), rewardBalance + rewardAmountToWithdraw, 2, "Reward balance is not correct 1");

    rewardBalance = _balance(lmmToken);
    managers.liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    assertAlmostEq(_balance(lmmToken), rewardBalance + rewardAmountToWithdraw, 2, "Reward balance is not correct 2");
    (, balances,,) = vault.position(positionId);
    assertEq(previousBalances.length + 1, balances.length, "Balances length is not correct");

    rewardBalance = _balance(lmmToken);
    intendedWithdraw[tokens.length - 1] = 0;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    vm.stopPrank();
  }

  function testFuzzFork_campaign_deposit(uint80 depositAmount, uint80 withdrawAmount, uint24 rewardAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount() / 2));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (, uint256[] memory previousBalances,,) = vault.position(positionId);

    _setLMCampaign(rewardAmount);

    (address[] memory tokens, uint256[] memory balances,,) = vault.position(positionId);
    assertEq(previousBalances.length + 1, balances.length, "Balances length is not correct");

    vm.startPrank(address(owner));

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);

    managers.liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));

    (, balances,,) = vault.position(positionId);
    assertEq(previousBalances.length + 1, balances.length, "Balances length is not correct");

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));

    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount;
    intendedWithdraw[tokens.length - 1] = 0;

    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    vm.stopPrank();
  }

  function testFuzzFork_addCampaign_deposit(uint80 depositAmount, uint80 withdrawAmount, uint24 rewardAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount() / 2));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    vm.startPrank(address(owner));

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    vm.stopPrank();
    _setLMCampaign(rewardAmount);

    (, uint256[] memory balances,,) = vault.position(positionId);
    assertEq(previousBalances.length + 1, balances.length, "Balances length is not correct");
    vm.startPrank(address(owner));

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);

    (, uint256[] memory balances2,,) = vault.position(positionId);
    assertEq(previousBalances.length + 1, balances2.length, "Balances length is not correct");
    vm.stopPrank();

    _warpTime(rewardAmount / 2);

    vm.startPrank(address(owner));
    (, uint256[] memory balances3,,) = vault.position(positionId);
    assertAlmostEq(
      balances3[balances3.length - 1],
      balances2[balances2.length - 1] + rewardAmount / 2,
      2,
      "Reward balance is not correct"
    );

    managers.liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    (, uint256[] memory balances4,,) = vault.position(positionId);
    assertAlmostEq(balances4[balances4.length - 1], 0, 2, "Reward balance is not correct");

    (, balances,,) = vault.position(positionId);
    assertEq(previousBalances.length + 1, balances.length, "Balances length is not correct");

    vm.stopPrank();
    _addToLMCampaign(rewardAmount);
    (, uint256[] memory balances5,,) = vault.position(positionId);
    _warpTime(rewardAmount / 2);
    vm.startPrank(address(owner));

    (address[] memory tokens, uint256[] memory balances6,,) = vault.position(positionId);
    assertAlmostEq(
      balances6[balances6.length - 1],
      balances5[balances5.length - 1] + rewardAmount / 2,
      2,
      "Reward balance is not correct"
    );

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0] / 2));

    uint256 rewardBalance = _balance(lmmToken);
    uint256 rewardAmountToWithdraw = balances6[balances6.length - 1];
    uint256[] memory intendedWithdraw = new uint256[](balances6.length);
    intendedWithdraw[0] = withdrawAmount;
    intendedWithdraw[balances6.length - 1] = rewardAmountToWithdraw;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    assertAlmostEq(_balance(lmmToken), rewardBalance + rewardAmountToWithdraw, 2, "Reward balance is not correct");
    vm.stopPrank();
  }
}
