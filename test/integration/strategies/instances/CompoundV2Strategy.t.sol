// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  CompoundV2StrategyFactory,
  CompoundV2Strategy,
  StrategyId,
  IComptroller,
  CompoundV2StrategyData,
  ICERC20
} from "src/strategies/instances/compound-v2/CompoundV2StrategyFactory.sol";
import { BaseLayersTest } from "./base/BaseLayersTest.t.sol";
import { BaseStrategy } from "test/integration/strategies/instances/interface/BaseStrategy.sol";
// solhint-disable-next-line max-states-count

abstract contract CompoundV2StrategyTest is BaseLayersTest {
  ICERC20 internal cToken;
  IComptroller internal comptroller;
  IERC20 internal comp;

  CompoundV2Strategy internal implementation;
  CompoundV2StrategyFactory internal factory;

  function _deployNewStrategy() internal override returns (IEarnStrategy, StrategyId) {
    implementation = new CompoundV2Strategy();
    factory = new CompoundV2StrategyFactory(implementation);
    (IEarnStrategy __strategy, StrategyId _strategyId) = factory.cloneStrategyAndRegister(
      owner,
      CompoundV2StrategyData(
        vault,
        globalRegistry,
        asset,
        cToken,
        comptroller,
        comp,
        validationData,
        guardianData,
        feesData,
        liquidityMiningData
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
      CompoundV2StrategyData(
        vault, globalRegistry, asset, cToken, comptroller, comp, validationData, bytes(""), bytes(""), bytes("")
      )
    );
    vm.startPrank(address(vault));
    IERC20(asset).approve(address(__strategy), type(uint256).max);
    vm.stopPrank();
    return (__strategy, _strategyId);
  }
}

abstract contract CompoundV2EthereumStrategyTest is CompoundV2StrategyTest {
  function _setUp() internal virtual override {
    lmmToken = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    comp = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888); // COMP
    comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
  }

  function _configureFork() internal virtual override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);
    vm.rollFork(20_000_000);
  }
}

contract CompoundV2EthereumWBTCStrategyTest is CompoundV2EthereumStrategyTest {
  function _setUp() internal override {
    super._setUp();
    cToken = ICERC20(0xccF4429DB6322D5C611ee964527D42E5d685DD6a);
    asset = address(cToken.underlying());
    _setBalance(asset, address(vault), type(uint256).max);
  }

  function _maxDepositAmount() internal pure virtual override returns (uint256) {
    return type(uint32).max;
  }
}
