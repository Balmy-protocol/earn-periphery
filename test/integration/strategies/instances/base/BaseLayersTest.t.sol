// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseStrategyTest } from "./BaseStrategyTest.t.sol";
import { BaseLiquidityMiningTest } from "./BaseLiquidityMiningTest.t.sol";
import { BaseGuardianTest } from "./BaseGuardianTest.t.sol";
import { ExternalGuardian } from "src/strategies/layers/guardian/external/ExternalGuardian.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseStrategy } from "test/integration/strategies/instances/interface/BaseStrategy.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

abstract contract BaseLayersTest is BaseStrategyTest, BaseLiquidityMiningTest, BaseGuardianTest {
  function testFuzzFork_depositAndWithdraw(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");

    (address[] memory tokens, uint256[] memory balances,,) = vault.position(positionId);
    assertAlmostEq(balances[0], depositAmount, 2);
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount;
    vm.startPrank(owner);
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    vm.stopPrank();
    (, uint256[] memory balances2) = _strategy.totalBalances();
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount, 2);
  }

  /* Liquidity Mining + Guardian */

  function testFuzzFork_cancelRescue_liquidityMining(
    uint80 depositAmount,
    uint80 withdrawAmount,
    uint24 rewardAmount
  )
    public
  {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    _setLMCampaign(rewardAmount);

    vm.startPrank(owner);
    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    vm.stopPrank();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    _strategy.cancelRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.OK);
    vm.stopPrank();

    vm.startPrank(owner);
    (address[] memory tokens, uint256[] memory balances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], balances[0], 2);

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);
    vm.stopPrank();
  }

  function testFuzzFork_confirmRescue_liquidityMining(
    uint80 depositAmount,
    uint80 withdrawAmount,
    uint24 rewardAmount
  )
    public
  {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");

    _setLMCampaign(rewardAmount);

    vm.startPrank(owner);
    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    vm.stopPrank();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();
    vm.prank(judge);
    _strategy.confirmRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUED);
    vm.startPrank(owner);

    (address[] memory tokens, uint256[] memory balances,,) = vault.position(positionId);
    assertAlmostEq(applyRescueFee(previousBalances[0]), balances[0], 2);

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    vm.stopPrank();
  }

  function testFuzzFork_confirmRescue_liquidityMining_abortCampaign(
    uint80 depositAmount,
    uint80 withdrawAmount,
    uint24 rewardAmount
  )
    public
  {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");

    _setLMCampaign(rewardAmount);

    vm.startPrank(owner);
    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    vm.stopPrank();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();
    vm.prank(judge);
    _strategy.confirmRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUED);

    (address[] memory tokens, uint256[] memory balances,,) = vault.position(positionId);
    assertAlmostEq(applyRescueFee(previousBalances[0]), balances[0], 2, "Balance is not correct 1");
    _warpTime(rewardAmount / 2);
    vm.startPrank(owner);

    (, uint256[] memory balances2,,) = vault.position(positionId);
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = 0;
    uint256 rewardAmountToWithdraw = balances2[tokens.length - 1];
    intendedWithdraw[tokens.length - 1] = rewardAmountToWithdraw;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    uint256 rewardBalance = _balance(lmmToken);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    assertAlmostEq(_balance(lmmToken), rewardBalance + rewardAmountToWithdraw, 2, "Reward balance is not correct 1");

    (, uint256[] memory balances3,,) = vault.position(positionId);
    rewardAmountToWithdraw = balances3[tokens.length - 1];
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances3[0]));
    uint256[] memory intendedWithdraw2 = new uint256[](tokens.length);
    intendedWithdraw2[0] = withdrawAmount;
    intendedWithdraw2[tokens.length - 1] = rewardAmountToWithdraw;
    vault.withdraw(positionId, tokens, intendedWithdraw2, address(this));
    vm.stopPrank();
  }

  /* MIGRATION TESTS */

  function testFuzzFork_migrateStrategy_deposit_withdraw(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (address[] memory tokens, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount, 2);

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());
    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw2 = new uint256[](tokens.length);
    intendedWithdraw2[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw2, address(this));
    (, uint256[] memory balances2,,) = vault.position(positionId);
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();
  }

  function testFuzzFork_migrateStrategy_depositTwice_withdraw(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);
    (address[] memory tokens, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount * 2, 3);

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    (, uint256[] memory balances,,) = vault.position(positionId);

    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());

    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw3 = new uint256[](tokens.length);
    intendedWithdraw3[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw3, address(this));
    (, uint256[] memory balances2,,) = vault.position(positionId);
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();
  }

  function testFuzzFork_migrateStrategy_deposit_withdraw_deposit(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (address[] memory tokens, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount, 2);

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    (, uint256[] memory balances,,) = vault.position(positionId);
    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());
    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);
    (, uint256[] memory balances2,,) = vault.position(positionId);
    assertAlmostEq(balances2[0], balances[0] + depositAmount, 2);
    vm.stopPrank();
  }

  function testFuzzFork_migrateStrategy_deposit_withdraw_setCampaign(
    uint80 depositAmount,
    uint80 withdrawAmount,
    uint24 rewardAmount
  )
    public
  {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));
    rewardAmount = uint24(bound(rewardAmount, strategyRegistry.STRATEGY_UPDATE_DELAY() * 2, type(uint24).max / 2)) * 2;

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (address[] memory tokens, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount, 2, "Deposit amount is not correct 1");

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    (, uint256[] memory balances,,) = vault.position(positionId);
    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount / 2, 2, "Balance is not correct 1");
    vm.stopPrank();

    _setLMCampaign(rewardAmount);

    _warpTime(rewardAmount / 2);
    (address[] memory tokens2, uint256[] memory balances2,,) = vault.position(positionId);
    assertAlmostEq(balances2[tokens2.length - 1], rewardAmount / 2, 2, "Reward amount is not correct 1");

    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();
    assertAlmostEq(balances[balances.length - 1], rewardAmount / 2, 2, "Reward amount is not correct 2");

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw2 = new uint256[](tokens2.length);
    intendedWithdraw2[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens2, intendedWithdraw2, address(this));
    (, uint256[] memory balances3,,) = vault.position(positionId);
    assertAlmostEq(balances3[0], balances[0] - withdrawAmount / 2, 2, "Balance is not correct 2");
    vm.stopPrank();
  }

  function testFuzzFork_migrateStrategy_deposit_propose_setCampaign_withdraw_abortCampaign_updateStrategy(
    uint80 depositAmount,
    uint80 withdrawAmount,
    uint24 rewardAmount
  )
    public
  {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));
    rewardAmount = uint24(bound(rewardAmount, strategyRegistry.STRATEGY_UPDATE_DELAY() * 2, type(uint24).max / 2)) * 2;

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount, 2, "Deposit amount is not correct 1");

    _setLMCampaign(rewardAmount);

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();
    _warpTime(rewardAmount / 2);

    vm.startPrank(owner);
    (address[] memory tokens, uint256[] memory warpedBalances,,) = vault.position(positionId);
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, warpedBalances[0]));
    uint256 rewardAmountToWithdraw = warpedBalances[tokens.length - 1];
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    (, uint256[] memory balances,,) = vault.position(positionId);

    assertAlmostEq(balances[0], warpedBalances[0] - withdrawAmount / 2, 2, "Balance is not correct 1");

    uint256 rewardBalance = _balance(lmmToken);
    uint256 lmmBalance = liquidityMiningManager.rewardAmount(strategyId, lmmToken);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    assertAlmostEq(
      _balance(lmmToken), rewardBalance + rewardAmountToWithdraw + lmmBalance, 2, "Reward balance is not correct 1"
    );

    strategyRegistry.updateStrategy(strategyId, bytes(""));
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();
    assertAlmostEq(balances[balances.length - 1], 0, 2, "Balance is not correct 2");

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw2 = new uint256[](tokens.length);
    intendedWithdraw2[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw2, address(this));
    (, uint256[] memory balances2,,) = vault.position(positionId);
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount / 2, 2, "Balance is not correct 3");
    vm.stopPrank();
  }

  function testFuzzFork_migrateStrategy_deposit_propose_setCampaign_increase_abortCampaign_withdraw_updateStrategy(
    uint80 depositAmount,
    uint80 withdrawAmount,
    uint24 rewardAmount
  )
    public
  {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));
    rewardAmount = uint24(bound(rewardAmount, strategyRegistry.STRATEGY_UPDATE_DELAY() * 2, type(uint24).max / 2)) * 2;
    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount, 2, "Deposit amount is not correct 1");

    _setLMCampaign(rewardAmount);

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();
    _warpTime(rewardAmount / 2);

    vm.startPrank(owner);
    (, uint256[] memory warpedBalances,,) = vault.position(positionId);
    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);

    (address[] memory tokens, uint256[] memory balances,,) = vault.position(positionId);
    assertAlmostEq(balances[0], warpedBalances[0] + depositAmount, 2, "Balance is not correct 1");

    uint256 rewardBalance = _balance(lmmToken);
    uint256 lmmBalance = liquidityMiningManager.rewardAmount(strategyId, lmmToken);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    assertAlmostEq(
      _balance(lmmToken),
      rewardBalance + warpedBalances[tokens.length - 1] + lmmBalance,
      2,
      "Reward balance is not correct 1"
    );

    (, uint256[] memory warpedBalances2,,) = vault.position(positionId);
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, warpedBalances2[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    (, uint256[] memory balances2,,) = vault.position(positionId);
    assertAlmostEq(balances2[0], warpedBalances2[0] - withdrawAmount / 2, 2, "Balance is not correct 2");

    strategyRegistry.updateStrategy(strategyId, bytes(""));
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();
    assertAlmostEq(balances[balances.length - 1], 0, 2, "Balance is not correct 3");

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw2 = new uint256[](tokens.length);
    intendedWithdraw2[0] = withdrawAmount / 2;
    vault.withdraw(positionId, tokens, intendedWithdraw2, address(this));
    (, uint256[] memory balances3,,) = vault.position(positionId);
    assertAlmostEq(balances3[0], balances[0] - withdrawAmount / 2, 2, "Balance is not correct 4");
    vm.stopPrank();
  }

  function testFuzzFork_rescue_migrateStrategy_shouldFail(uint80 depositAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount, 2, "Deposit amount is not correct 1");

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());
    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
  }

  function testFuzzFork_cancelRescue_migrateStrategy(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount, 2, "Deposit amount is not correct 1");

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    _strategy.cancelRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.OK);
    vm.stopPrank();

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());

    // withdraw fees
    (address[] memory tokens, uint256[] memory collected) = _strategy.collectedFees();
    vm.startPrank(owner);
    _strategy.withdrawFees(tokens, collected, address(this));

    (, uint256[] memory previousWarpedBalances,,) = vault.position(positionId);

    (, uint256[] memory previousMigratedBalances) = migrateStrategy.totalBalances();

    strategyRegistry.updateStrategy(strategyId, bytes(""));

    (, uint256[] memory balances,,) = vault.position(positionId);
    assertAlmostEq(previousWarpedBalances[0], balances[0] - previousMigratedBalances[0], 3, "Balance is not correct 1");

    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));
    (, uint256[] memory balances2,,) = vault.position(positionId);
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount, 3, "Balance is not correct 2");

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);
    (, uint256[] memory balances3,,) = vault.position(positionId);
    assertAlmostEq(balances3[0], balances2[0] + depositAmount, 3, "Balance is not correct 3");
    vm.stopPrank();
  }

  function testFuzzFork_confirmRescue_migrateStrategy(uint80 depositAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (, uint256[] memory previousBalances,,) = vault.position(positionId);
    assertAlmostEq(previousBalances[0], depositAmount, 2, "Deposit amount is not correct 1");

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();

    vm.prank(judge);
    _strategy.confirmRescue();

    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUED);

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());

    vm.startPrank(owner);
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
  }
}
