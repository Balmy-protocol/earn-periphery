// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BaseStrategyTest } from "./BaseStrategyTest.t.sol";
import { ExternalGuardian } from "src/strategies/layers/guardian/external/ExternalGuardian.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseGuardianTest is BaseStrategyTest {
  function testFuzzFork_cancelRescue(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");
    (address[] memory tokens, uint256[] memory previousBalances,,) = vault.position(positionId);

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

    vm.startPrank(owner);
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw = new uint256[](tokens.length);
    intendedWithdraw[0] = withdrawAmount;
    vault.withdraw(positionId, tokens, intendedWithdraw, address(this));

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vault.increasePosition(positionId, asset, depositAmount);
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

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");

    vm.startPrank(guardian);
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.stopPrank();

    vm.startPrank(address(owner));
    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    vault.increasePosition(positionId, asset, depositAmount);
    vm.stopPrank();
  }

  function testFuzzFork_rescue_withdraw(uint80 depositAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");

    vm.startPrank(guardian);
    _strategy.rescue(address(this));
    (,, ExternalGuardian.RescueStatus status) = _strategy.rescueConfig();
    assert(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    (address[] memory assets, uint256[] memory amounts,,) = vault.position(positionId);
    vm.startPrank(address(owner));
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    vault.withdraw(positionId, assets, amounts, address(this));
    vm.stopPrank();
  }

  function testFuzzFork_confirmRescue(uint80 depositAmount, uint80 withdrawAmount) public {
    depositAmount = uint80(bound(depositAmount, 1e8, _maxDepositAmount()));

    _setBalance(asset, address(this), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    (uint256 positionId,) = vault.createPosition(strategyId, asset, depositAmount, owner, permissions, "", "");

    (address[] memory assets, uint256[] memory previousBalances,,) = vault.position(positionId);

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

    vm.startPrank(address(owner));
    withdrawAmount = uint80(bound(withdrawAmount, 1e7, balances[0]));
    uint256[] memory intendedWithdraw = new uint256[](assets.length);
    intendedWithdraw[0] = withdrawAmount;
    vault.withdraw(positionId, assets, intendedWithdraw, address(this));

    _setBalance(asset, address(owner), _maxDepositAmount());
    IERC20(asset).approve(address(vault), type(uint256).max);
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    vault.increasePosition(positionId, asset, depositAmount);
    vm.stopPrank();
  }
}
