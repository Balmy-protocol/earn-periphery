// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  ERC4626StrategyFactory,
  ERC4626Strategy,
  StrategyId,
  IERC4626,
  ERC4626StrategyData
} from "src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";
import { BaseLayersTest } from "./base/BaseLayersTest.t.sol";
import { BaseStrategy } from "./base/BaseStrategy.sol";
// solhint-disable-next-line max-states-count

contract ERC4626StrategyTest is BaseLayersTest {
  IERC4626 private erc4626Vault;
  ERC4626StrategyFactory private factory;

  function _setUp() internal override {
    erc4626Vault = IERC4626(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
    asset = erc4626Vault.asset();
    lmmToken = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    _setBalance(asset, address(vault), type(uint256).max);
    ERC4626Strategy implementation = new ERC4626Strategy();
    factory = new ERC4626StrategyFactory(implementation);
  }

  function _deployNewStrategy() internal override returns (IEarnStrategy, StrategyId) {
    (IEarnStrategy __strategy, StrategyId _strategyId) = factory.cloneStrategyAndRegister(
      owner,
      ERC4626StrategyData(
        vault,
        globalRegistry,
        erc4626Vault,
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
      ERC4626StrategyData(
        vault, globalRegistry, erc4626Vault, strategyData.validationData, bytes(""), bytes(""), bytes("")
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

  function _configureFork() internal virtual override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);
    vm.rollFork(20_000_000);
  }
}
