// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  CompoundV3StrategyFactory,
  CompoundV3Strategy,
  StrategyId,
  CompoundV3StrategyData,
  ICERC20,
  ICometRewards
} from "src/strategies/instances/compound-v3/CompoundV3StrategyFactory.sol";
import { BaseLayersTest } from "./base/BaseLayersTest.t.sol";
import { BaseStrategy } from "./base/BaseStrategy.sol";
// solhint-disable-next-line max-states-count

abstract contract CompoundV3StrategyTest is BaseLayersTest {
  ICERC20 internal cToken;
  address internal holder;
  ICometRewards internal cometRewards;

  CompoundV3Strategy internal implementation;
  CompoundV3StrategyFactory internal factory;

  function _deployNewStrategy() internal override returns (IEarnStrategy, StrategyId) {
    implementation = new CompoundV3Strategy();
    factory = new CompoundV3StrategyFactory(implementation);
    (IEarnStrategy __strategy, StrategyId _strategyId) = factory.cloneStrategyAndRegister(
      owner,
      CompoundV3StrategyData(
        vault,
        globalRegistry,
        cToken,
        cometRewards,
        strategyData.validationData,
        strategyData.guardianData,
        strategyData.feesData,
        strategyData.liquidityMiningData
      )
    );
    vm.startPrank(address(vault));
    IERC20(asset).approve(address(__strategy), type(uint256).max);
    _strategy = BaseStrategy(payable(address(__strategy)));
    vm.stopPrank();
    return (__strategy, _strategyId);
  }

  function _deployNewStrategyToMigrate(StrategyId _strategyId)
    internal
    virtual
    override
    returns (IEarnStrategy, StrategyId)
  {
    IEarnStrategy __strategy = factory.cloneStrategyWithId(
      _strategyId,
      CompoundV3StrategyData(
        vault, globalRegistry, cToken, cometRewards, strategyData.validationData, bytes(""), bytes(""), bytes("")
      )
    );
    vm.startPrank(address(vault));
    IERC20(asset).approve(address(__strategy), type(uint256).max);
    vm.stopPrank();
    _setBalance(address(cToken), address(__strategy), 1000, holder);
    return (__strategy, _strategyId);
  }
}

abstract contract CompoundV3BaseStrategyTest is CompoundV3StrategyTest {
  function _setUp() internal virtual override {
    lmmToken = 0x994ac01750047B9d35431a7Ae4Ed312ee955E030;
    cometRewards = ICometRewards(0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1);
  }

  function _configureFork() internal virtual override {
    uint256 baseFork = vm.createFork(vm.rpcUrl("base"));
    vm.selectFork(baseFork);
    vm.rollFork(26_000_000);
    holder = 0x3eC6f5793ce4B90F2B7381516c91ACc4cf169553;
  }
}

contract CompoundV3BaseWETHStrategyTest is CompoundV3BaseStrategyTest {
  function _setUp() internal override {
    super._setUp();
    cToken = ICERC20(0x46e6b214b524310239732D51387075E0e70970bf);
    asset = cToken.baseToken();
    _setBalance(asset, address(vault), type(uint256).max);
  }

  function _maxDepositAmount() internal pure override returns (uint256) {
    return 1e18;
  }
}
