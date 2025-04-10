// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  MorphoStrategyFactory,
  MorphoStrategy,
  StrategyId,
  IERC4626,
  IGlobalEarnRegistry,
  MorphoStrategyData
} from "src/strategies/instances/morpho/MorphoStrategyFactory.sol";
import { MorphoRewardsManager } from "src/strategies/layers/connector/morpho/MorphoRewardsManager.sol";
import { MorphoConnector } from "src/strategies/layers/connector/morpho/MorphoConnector.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";
import { BaseLayersTest } from "./base/BaseLayersTest.t.sol";
import { BaseStrategy } from "./base/BaseStrategy.sol";

// solhint-disable-next-line max-states-count
abstract contract MorphoStrategyTest is BaseLayersTest {
  IERC4626 internal mToken;
  MorphoStrategyFactory internal factory;
  address[] internal rewardTokens;

  function _deployNewStrategy() internal override returns (IEarnStrategy, StrategyId) {
    MorphoStrategy implementation = new MorphoStrategy();
    factory = new MorphoStrategyFactory(implementation);
    (IEarnStrategy __strategy, StrategyId _strategyId) = factory.cloneStrategyAndRegister(
      owner,
      MorphoStrategyData(
        vault,
        globalRegistry,
        mToken,
        strategyData.validationData,
        strategyData.guardianData,
        strategyData.feesData,
        strategyData.liquidityMiningData,
        rewardTokens
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
      MorphoStrategyData(
        vault, globalRegistry, mToken, strategyData.validationData, bytes(""), bytes(""), bytes(""), rewardTokens
      )
    );
    vm.startPrank(address(vault));
    IERC20(asset).approve(address(__strategy), type(uint256).max);
    vm.stopPrank();
    return (__strategy, _strategyId);
  }

  function _maxDepositAmount() internal pure override returns (uint256) {
    return 1e18;
  }
}

abstract contract MorphoBaseStrategyTest is MorphoStrategyTest {
  function _setUp() internal virtual override {
    lmmToken = 0x994ac01750047B9d35431a7Ae4Ed312ee955E030;
  }

  function _configureFork() internal virtual override {
    uint256 baseFork = vm.createFork(vm.rpcUrl("base"));
    vm.selectFork(baseFork);
    vm.rollFork(26_000_000);
  }
}

contract MorphoBaseWETHStrategyTest is MorphoBaseStrategyTest {
  function _setUp() internal virtual override {
    super._setUp();
    mToken = IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1);
    asset = mToken.asset();
    rewardTokens = new address[](2);
    rewardTokens[0] = 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842; // $MORPHO
    rewardTokens[1] = 0xA88594D404727625A9437C3f886C7643872296AE; // $WELL

    _setBalance(asset, address(vault), type(uint256).max);
  }

  function _warpTime(uint256 secondsToWarp) internal virtual override {
    MorphoRewardsManager.Configuration[] memory configurations = new MorphoRewardsManager.Configuration[](1);

    configurations[0] =
      MorphoRewardsManager.Configuration({ connector: MorphoConnector(address(_strategy)), tokens: rewardTokens });

    _give(rewardTokens[0], address(_strategy), secondsToWarp * 10);
    _give(rewardTokens[1], address(_strategy), secondsToWarp * 20);
    managers.morphoRewardsManager = new MorphoRewardsManager(owner, CommonUtils.arrayOf(owner));
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("MORPHO_REWARDS_MANAGER")),
      abi.encode(managers.morphoRewardsManager)
    );

    vm.startPrank(owner);
    managers.morphoRewardsManager.configureRewards(configurations, secondsToWarp);
    vm.stopPrank();

    vm.warp(block.timestamp + secondsToWarp);
  }
}
