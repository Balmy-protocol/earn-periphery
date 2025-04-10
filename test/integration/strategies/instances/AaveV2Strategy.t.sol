// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  AaveV2StrategyFactory,
  AaveV2Strategy,
  StrategyId,
  IAToken,
  IAaveV2Pool,
  AaveV2StrategyData
} from "src/strategies/instances/aave-v2/AaveV2StrategyFactory.sol";
import { BaseLayersTest } from "./base/BaseLayersTest.t.sol";
import { BaseStrategy } from "test/integration/strategies/instances/interface/BaseStrategy.sol";
// solhint-disable-next-line max-states-count

abstract contract AaveV2StrategyTest is BaseLayersTest {
  IAToken internal aToken;

  AaveV2Strategy internal implementation;
  AaveV2StrategyFactory internal factory;

  function _deployNewStrategy() internal override returns (IEarnStrategy, StrategyId) {
    implementation = new AaveV2Strategy();
    factory = new AaveV2StrategyFactory(implementation);
    (IEarnStrategy __strategy, StrategyId _strategyId) = factory.cloneStrategyAndRegister(
      owner,
      AaveV2StrategyData(
        vault,
        globalRegistry,
        aToken,
        IAaveV2Pool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9),
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
      AaveV2StrategyData(
        vault,
        globalRegistry,
        aToken,
        IAaveV2Pool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9),
        strategyData.validationData,
        strategyData.guardianData,
        bytes(""),
        strategyData.liquidityMiningData
      )
    );
    vm.startPrank(address(vault));
    IERC20(asset).approve(address(__strategy), type(uint256).max);
    vm.stopPrank();
    return (__strategy, _strategyId);
  }

  function _configureFork() internal virtual override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);
    vm.rollFork(20_000_000);
  }
}

contract AaveV2WETHStrategyTest is AaveV2StrategyTest {
  function _setUp() internal override {
    aToken = IAToken(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);
    asset = aToken.UNDERLYING_ASSET_ADDRESS();
    lmmToken = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    _setBalance(asset, address(vault), type(uint256).max);
  }

  function _maxDepositAmount() internal pure override returns (uint256) {
    return 1e18;
  }
}
