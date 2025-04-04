// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseStrategyTest } from "./BaseStrategyTest.t.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";
import { ExternalGuardian } from "src/strategies/layers/guardian/external/ExternalGuardian.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseStrategy } from "test/integration/strategies/instances/interface/BaseStrategy.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";

abstract contract BaseLayersTest is BaseStrategyTest {
  address internal asset;
  address internal lmmToken;

  function testFuzzFork_depositAndWithdraw(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    IERC20(asset).approve(address(_strategy), type(uint256).max);
    _strategy.deposit(asset, depositAmount);
    (, uint256[] memory previousBalances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], depositAmount, 2);
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount), address(this));
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount, 2);
    vm.stopPrank();
  }

  /* GUARDIAN TESTS */

  function testFuzzFork_cancelRescue(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
    (, uint256[] memory previousBalances) = _strategy.totalBalances();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    _strategy.cancelRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.OK);
    vm.stopPrank();

    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], balances[0], 2);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount), address(this));
    vm.stopPrank();

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
  }

  function testFuzzFork_cancelRescue_emptyStrategy() public {
    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    _strategy.cancelRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.OK);
    vm.stopPrank();
  }

  function testFuzzFork_rescue_deposit(uint80 depositAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

    vm.startPrank(guardian);
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();

    vm.startPrank(address(vault));
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
  }

  function testFuzzFork_rescue_withdraw(uint80 depositAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

    vm.startPrank(guardian);
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    vm.startPrank(address(vault));
    address[] memory assets = CommonUtils.arrayOf(asset);
    uint256[] memory amounts = CommonUtils.arrayOf(applyRescueFee(depositAmount));
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    _strategy.withdraw(0, assets, amounts, address(this));
    vm.stopPrank();
  }

  function testFuzzFork_confirmRescue(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
    (, uint256[] memory previousBalances) = _strategy.totalBalances();

    vm.startPrank(guardian);
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();
    vm.prank(judge);
    _strategy.confirmRescue();

    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUED);

    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(applyRescueFee(previousBalances[0]), balances[0], 2);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount), address(this));
    vm.stopPrank();

    vm.startPrank(address(vault));
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
  }

  /* LIQUIDITY MINING TESTS */

  function testFuzzFork_campaign_withdraw(uint80 depositAmount, uint80 withdrawAmount, uint24 rewardAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
    (, uint256[] memory previousBalances) = _strategy.totalBalances();

    _setLMCampaign(rewardAmount);

    _warpTime(rewardAmount / 2);

    vm.startPrank(owner);
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertEq(previousBalances.length + 1, balances.length);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0] / 2));
    uint256 rewardBalance = _balance(lmmToken);
    _strategy.withdraw(
      0, CommonUtils.arrayOf(asset, lmmToken), CommonUtils.arrayOf(withdrawAmount, rewardAmount / 2), address(this)
    );
    assertEq(_balance(lmmToken), rewardBalance + rewardAmount / 2);
    vm.stopPrank();
    vm.startPrank(owner);
    rewardBalance = _balance(lmmToken);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    assertEq(_balance(lmmToken), rewardBalance + rewardAmount / 2);
    vm.stopPrank();
    (, balances) = _strategy.totalBalances();
    assertEq(previousBalances.length + 1, balances.length);

    vm.startPrank(address(vault));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset, lmmToken), CommonUtils.arrayOf(withdrawAmount, 0), address(this));
    vm.stopPrank();
  }

  function testFuzzFork_campaign_deposit(uint80 depositAmount, uint80 withdrawAmount, uint24 rewardAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount() / 2));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
    (, uint256[] memory previousBalances) = _strategy.totalBalances();

    _setLMCampaign(rewardAmount);

    (, uint256[] memory balances) = _strategy.totalBalances();
    assertEq(previousBalances.length + 1, balances.length);

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

    vm.startPrank(owner);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    vm.stopPrank();

    (, balances) = _strategy.totalBalances();
    assertEq(previousBalances.length + 1, balances.length);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0] / 2));

    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount), address(this));
    vm.stopPrank();
  }

  function testFuzzFork_addCampaign_deposit(uint80 depositAmount, uint80 withdrawAmount, uint24 rewardAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount() / 2));
    rewardAmount = uint24(bound(rewardAmount, 1e2, type(uint24).max / 2)) * 2;

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
    (, uint256[] memory previousBalances) = _strategy.totalBalances();

    _setLMCampaign(rewardAmount);

    (, uint256[] memory balances) = _strategy.totalBalances();
    assertEq(previousBalances.length + 1, balances.length);

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

    (, uint256[] memory balances2) = _strategy.totalBalances();
    _warpTime(rewardAmount / 2);
    (, uint256[] memory balances3) = _strategy.totalBalances();
    assertEq(balances3[balances3.length - 1], balances2[balances2.length - 1] + rewardAmount / 2);

    vm.startPrank(owner);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    (, uint256[] memory balances4) = _strategy.totalBalances();
    assertEq(balances4[balances4.length - 1], 0);
    vm.stopPrank();

    (, balances) = _strategy.totalBalances();
    assertEq(previousBalances.length + 1, balances.length);

    _addToLMCampaign(rewardAmount);

    (, uint256[] memory balances5) = _strategy.totalBalances();
    _warpTime(rewardAmount / 2);
    (, uint256[] memory balances6) = _strategy.totalBalances();
    assertEq(balances6[balances6.length - 1], balances5[balances5.length - 1] + rewardAmount / 2);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0] / 2));
    uint256 rewardBalance = _balance(lmmToken);
    _strategy.withdraw(
      0, CommonUtils.arrayOf(asset, lmmToken), CommonUtils.arrayOf(withdrawAmount, rewardAmount / 2), address(this)
    );
    assertEq(_balance(lmmToken), rewardBalance + rewardAmount / 2);
    vm.stopPrank();
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

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

    _setLMCampaign(rewardAmount);

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
    (, uint256[] memory previousBalances) = _strategy.totalBalances();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    _strategy.cancelRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.OK);
    vm.stopPrank();

    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], balances[0], 2);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount), address(this));
    vm.stopPrank();

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
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

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

    _setLMCampaign(rewardAmount);

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
    (, uint256[] memory previousBalances) = _strategy.totalBalances();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();
    vm.prank(judge);
    _strategy.confirmRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUED);

    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(applyRescueFee(previousBalances[0]), balances[0], 2);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount), address(this));
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

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

    _setLMCampaign(rewardAmount);

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();
    (, uint256[] memory previousBalances) = _strategy.totalBalances();

    vm.startPrank(address(guardian));
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();
    vm.prank(judge);
    _strategy.confirmRescue();
    (,, status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUED);

    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(applyRescueFee(previousBalances[0]), balances[0], 2);
    _warpTime(rewardAmount / 2);
    vm.startPrank(address(vault));
    _strategy.withdraw(1, CommonUtils.arrayOf(asset, lmmToken), CommonUtils.arrayOf(0, rewardAmount / 2), address(this));
    vm.stopPrank();

    vm.startPrank(owner);
    uint256 rewardBalance = _balance(lmmToken);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    assertEq(_balance(lmmToken), rewardBalance + rewardAmount / 2);
    vm.stopPrank();

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount), address(this));
    vm.stopPrank();
  }

  /* MIGRATION TESTS */

  function testFuzzFork_migrateStrategy_deposit_withdraw(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _maxApproval(asset, address(_strategy));
    _strategy.deposit(asset, depositAmount);
    (, uint256[] memory previousBalances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], depositAmount, 2);
    vm.stopPrank();

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());
    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    migratedStrategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances2) = migratedStrategy.totalBalances();
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();
  }

  function testFuzzFork_migrateStrategy_depositTwice_withdraw(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _maxApproval(asset, address(_strategy));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();

    vm.startPrank(address(vault));
    _maxApproval(asset, address(_strategy));
    _strategy.deposit(asset, depositAmount);
    (, uint256[] memory previousBalances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], depositAmount * 2, 3);
    vm.stopPrank();

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());

    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    migratedStrategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances2) = migratedStrategy.totalBalances();
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();
  }

  function testFuzzFork_migrateStrategy_deposit_withdraw_deposit(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _maxApproval(asset, address(_strategy));
    _strategy.deposit(asset, depositAmount);
    (, uint256[] memory previousBalances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], depositAmount, 2);
    vm.stopPrank();

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    _warpTime(strategyRegistry.STRATEGY_UPDATE_DELAY());
    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();

    vm.startPrank(address(vault));
    migratedStrategy.deposit(asset, depositAmount);
    (, uint256[] memory balances2) = migratedStrategy.totalBalances();
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

    vm.startPrank(address(vault));
    _maxApproval(asset, address(_strategy));
    _strategy.deposit(asset, depositAmount);
    (, uint256[] memory previousBalances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], depositAmount, 2);
    vm.stopPrank();

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, previousBalances[0]));
    _strategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(balances[0], previousBalances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    _setLMCampaign(rewardAmount);

    _warpTime(rewardAmount / 2);
    (, balances) = _strategy.totalBalances();
    assertEq(balances[balances.length - 1], rewardAmount / 2);

    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();
    assertEq(balances[balances.length - 1], rewardAmount / 2);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    migratedStrategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances2) = migratedStrategy.totalBalances();
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount / 2, 2);
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

    vm.startPrank(address(vault));
    _maxApproval(asset, address(_strategy));
    _strategy.deposit(asset, depositAmount);
    (, uint256[] memory previousBalances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], depositAmount, 2);
    vm.stopPrank();

    _setLMCampaign(rewardAmount);

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();
    _warpTime(rewardAmount / 2);

    vm.startPrank(address(vault));
    (, uint256[] memory warpedBalances) = _strategy.totalBalances();
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, warpedBalances[0]));
    _strategy.withdraw(
      0, CommonUtils.arrayOf(asset, lmmToken), CommonUtils.arrayOf(withdrawAmount / 2, rewardAmount / 2), address(this)
    );
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(balances[0], warpedBalances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    vm.startPrank(owner);
    uint256 rewardBalance = _balance(lmmToken);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    assertEq(_balance(lmmToken), rewardBalance + rewardAmount / 2);
    vm.stopPrank();

    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();
    assertEq(balances[balances.length - 1], 0);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    migratedStrategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances2) = migratedStrategy.totalBalances();
    assertAlmostEq(balances2[0], balances[0] - withdrawAmount / 2, 2);
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

    vm.startPrank(address(vault));
    _maxApproval(asset, address(_strategy));
    _strategy.deposit(asset, depositAmount);
    (, uint256[] memory previousBalances) = _strategy.totalBalances();
    assertAlmostEq(previousBalances[0], depositAmount, 2);
    vm.stopPrank();

    _setLMCampaign(rewardAmount);

    vm.startPrank(owner);
    strategyRegistry.proposeStrategyUpdate(strategyId, IEarnStrategy(payable(address(migrateStrategy))), bytes(""));
    vm.stopPrank();
    _warpTime(rewardAmount / 2);

    vm.startPrank(address(vault));
    (, uint256[] memory warpedBalances) = _strategy.totalBalances();
    _strategy.deposit(asset, depositAmount);
    (, uint256[] memory balances) = _strategy.totalBalances();
    assertAlmostEq(balances[0], warpedBalances[0] + depositAmount, 2);
    vm.stopPrank();

    vm.startPrank(owner);
    uint256 rewardBalance = _balance(lmmToken);
    liquidityMiningManager.abortCampaign(strategyId, lmmToken, address(this));
    assertEq(_balance(lmmToken), rewardBalance + rewardAmount);
    vm.stopPrank();

    vm.startPrank(address(vault));
    (, uint256[] memory warpedBalances2) = _strategy.totalBalances();
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, warpedBalances2[0]));
    _strategy.withdraw(
      0, CommonUtils.arrayOf(asset, lmmToken), CommonUtils.arrayOf(withdrawAmount / 2, 0), address(this)
    );
    (, uint256[] memory balances2) = _strategy.totalBalances();
    assertAlmostEq(balances2[0], warpedBalances2[0] - withdrawAmount / 2, 2);
    vm.stopPrank();

    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));
    (, balances) = migratedStrategy.totalBalances();
    assertEq(balances[balances.length - 1], 0);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    migratedStrategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount / 2), address(this));
    (, uint256[] memory balances3) = migratedStrategy.totalBalances();
    assertAlmostEq(balances3[0], balances[0] - withdrawAmount / 2, 2);
    vm.stopPrank();
  }

  function testFuzzFork_rescue_migrateStrategy_shouldFail(uint80 depositAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

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

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

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
    vm.prank(address(owner));
    _strategy.withdrawFees(tokens, collected, address(this));

    (, uint256[] memory previousWarpedBalances) = _strategy.totalBalances();

    (, uint256[] memory previousMigratedBalances) = migrateStrategy.totalBalances();

    vm.startPrank(owner);
    strategyRegistry.updateStrategy(strategyId, bytes(""));
    vm.stopPrank();
    BaseStrategy migratedStrategy = BaseStrategy(payable(address(strategyRegistry.getStrategy(strategyId))));

    (, uint256[] memory balances) = migratedStrategy.totalBalances();
    assertAlmostEq(previousWarpedBalances[0], balances[0] - previousMigratedBalances[0], 3);

    vm.startPrank(address(vault));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    migratedStrategy.withdraw(0, CommonUtils.arrayOf(asset), CommonUtils.arrayOf(withdrawAmount), address(this));
    vm.stopPrank();

    vm.startPrank(address(vault));
    migratedStrategy.deposit(asset, depositAmount);
    vm.stopPrank();
  }

  function testFuzzFork_confirmRescue_migrateStrategy(uint80 depositAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    vm.startPrank(address(vault));
    _strategy.deposit(asset, depositAmount);
    vm.stopPrank();

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

  function _setLMCampaign(uint24 rewardAmount) internal {
    vm.startPrank(owner);
    _setBalance(lmmToken, owner, type(uint256).max);

    if (lmmToken == Token.NATIVE_TOKEN) {
      liquidityMiningManager.setCampaign{ value: rewardAmount }(strategyId, lmmToken, 1, rewardAmount);
    } else {
      _maxApproval(lmmToken, address(liquidityMiningManager));
      liquidityMiningManager.setCampaign(strategyId, lmmToken, 1, rewardAmount);
    }
    vm.stopPrank();
  }

  function _addToLMCampaign(uint24 rewardAmount) internal {
    vm.startPrank(owner);
    _setBalance(lmmToken, owner, type(uint256).max);
    if (lmmToken == Token.NATIVE_TOKEN) {
      liquidityMiningManager.addToCampaign{ value: rewardAmount }(strategyId, lmmToken, rewardAmount, rewardAmount);
    } else {
      _maxApproval(lmmToken, address(liquidityMiningManager));
      liquidityMiningManager.addToCampaign(strategyId, lmmToken, rewardAmount, rewardAmount);
    }

    vm.stopPrank();
  }

  function _balance(address token) internal view returns (uint256) {
    if (token == Token.NATIVE_TOKEN) {
      return address(this).balance;
    } else {
      return IERC20(token).balanceOf(address(this));
    }
  }
}
