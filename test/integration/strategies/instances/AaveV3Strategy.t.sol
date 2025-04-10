// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  AaveV3StrategyFactory,
  AaveV3Strategy,
  StrategyId,
  IAToken,
  IAaveV3Pool,
  IAaveV3Rewards,
  AaveV3StrategyData
} from "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";
import { IFeeManagerCore } from "src/interfaces/IFeeManager.sol";
import { Fees } from "src/types/Fees.sol";
import { BaseLayersTest } from "./base/BaseLayersTest.t.sol";
import { BaseStrategy } from "./base/BaseStrategy.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
// solhint-disable-next-line max-states-count

abstract contract AaveV3StrategyTest is BaseLayersTest {
  IAToken internal aToken;
  IAaveV3Pool internal pool;
  IAaveV3Rewards internal rewardsController;

  AaveV3Strategy internal implementation;
  AaveV3StrategyFactory internal factory;

  function _deployNewStrategy() internal virtual override returns (IEarnStrategy, StrategyId) {
    implementation = new AaveV3Strategy();
    factory = new AaveV3StrategyFactory(implementation);
    (IEarnStrategy __strategy, StrategyId _strategyId) = factory.cloneStrategyAndRegister(
      owner,
      AaveV3StrategyData(
        vault,
        globalRegistry,
        aToken,
        pool,
        rewardsController,
        strategyData.validationData,
        strategyData.guardianData,
        strategyData.feesData,
        strategyData.liquidityMiningData
      )
    );
    vm.startPrank(address(vault));
    IERC20(asset).approve(address(__strategy), type(uint256).max);
    __strategy = BaseStrategy(payable(address(__strategy)));
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
      AaveV3StrategyData(
        vault,
        globalRegistry,
        aToken,
        pool,
        rewardsController,
        strategyData.validationData,
        bytes(""),
        bytes(""),
        bytes("")
      )
    );
    vm.startPrank(address(vault));
    IERC20(asset).approve(address(__strategy), type(uint256).max);
    vm.stopPrank();
    return (__strategy, _strategyId);
  }

  function _maxDepositAmount() internal pure virtual override returns (uint256) {
    return type(uint64).max;
  }
}

abstract contract AaveV3BaseStrategyTest is AaveV3StrategyTest {
  function _setUp() internal virtual override {
    pool = IAaveV3Pool(0xA238Dd80C259a72e81d7e4664a9801593F98d1c5);
    rewardsController = IAaveV3Rewards(0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44);
    lmmToken = 0x994ac01750047B9d35431a7Ae4Ed312ee955E030;
  }

  function _configureFork() internal virtual override {
    uint256 baseFork = vm.createFork(vm.rpcUrl("base"));
    vm.selectFork(baseFork);
    vm.rollFork(26_000_000);
  }
}

contract AaveV3BaseWETHStrategyTest is AaveV3BaseStrategyTest {
  function _setUp() internal override {
    super._setUp();
    aToken = IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7);
    asset = aToken.UNDERLYING_ASSET_ADDRESS();
    _setBalance(asset, address(vault), type(uint256).max);
  }
}

contract AaveV3BaseCBBTCStrategyTest is AaveV3BaseStrategyTest {
  function _setUp() internal virtual override {
    super._setUp();
    aToken = IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6);
    asset = aToken.UNDERLYING_ASSET_ADDRESS();
    _setBalance(asset, address(vault), type(uint256).max);
  }

  function _maxDepositAmount() internal pure virtual override returns (uint256) {
    return type(uint32).max;
  }
}

contract AaveV3BaseCBBTCStrategyWithFeesTest is AaveV3BaseCBBTCStrategyTest {
  function _setUp() internal override {
    super._setUp();
    strategyData.feesData = abi.encode(Fees(0, 0, 5000, 500));
    vm.mockCall(
      address(managers.feeManager),
      abi.encodeWithSelector(IFeeManagerCore.getFees.selector, strategyId),
      strategyData.feesData
    );
  }
}

contract AaveV3BaseCBBTCStrategyWithFeesAndNativeLMTest is AaveV3BaseCBBTCStrategyTest {
  function _setUp() internal override {
    super._setUp();
    lmmToken = Token.NATIVE_TOKEN; // Native token
    strategyData.feesData = abi.encode(Fees(0, 0, 5000, 500));
    vm.mockCall(
      address(managers.feeManager),
      abi.encodeWithSelector(IFeeManagerCore.getFees.selector, strategyId),
      strategyData.feesData
    );
  }
}

abstract contract AaveV3OptimismStrategyTest is AaveV3StrategyTest {
  function _setUp() internal virtual override {
    pool = IAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    rewardsController = IAaveV3Rewards(0x929EC64c34a17401F460460D4B9390518E5B473e);
    lmmToken = 0x2E3D870790dC77A83DD1d18184Acc7439A53f475; // FRAX
  }

  function _configureFork() internal virtual override {
    uint256 optimismFork = vm.createFork(vm.rpcUrl("optimism"));
    vm.selectFork(optimismFork);
    vm.rollFork(133_000_000);
  }
}

contract AaveV3OptimismWETHStrategyTest is AaveV3OptimismStrategyTest {
  function _setUp() internal virtual override {
    super._setUp();
    aToken = IAToken(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8);
    asset = aToken.UNDERLYING_ASSET_ADDRESS();
    _setBalance(asset, address(vault), type(uint256).max);
  }
}

contract AaveV3OptimismWETHWithFeesStrategyTest is AaveV3OptimismWETHStrategyTest {
  function _setUp() internal override {
    super._setUp();
    strategyData.feesData = abi.encode(Fees(0, 0, 1000, 1000));
    vm.mockCall(
      address(managers.feeManager),
      abi.encodeWithSelector(IFeeManagerCore.getFees.selector, strategyId),
      strategyData.feesData
    );
  }
}

contract AaveV3OptimismWBTCStrategyTest is AaveV3OptimismStrategyTest {
  function _setUp() internal override {
    super._setUp();
    aToken = IAToken(0x078f358208685046a11C85e8ad32895DED33A249);
    asset = aToken.UNDERLYING_ASSET_ADDRESS();
    _setBalance(asset, address(vault), type(uint256).max);
  }

  function _maxDepositAmount() internal pure virtual override returns (uint256) {
    return type(uint32).max;
  }
}

abstract contract AaveV3ArbitrumStrategyTest is AaveV3StrategyTest {
  function _setUp() internal virtual override {
    pool = IAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    rewardsController = IAaveV3Rewards(0x929EC64c34a17401F460460D4B9390518E5B473e);
    lmmToken = 0x93b346b6BC2548dA6A1E7d98E9a421B42541425b; // LUSD
  }

  function _configureFork() internal virtual override {
    uint256 arbitrumFork = vm.createFork(vm.rpcUrl("arbitrum_one"));
    vm.selectFork(arbitrumFork);
    vm.rollFork(319_853_000);
  }
}

contract AaveV3ArbitrumFRAXStrategyTest is AaveV3ArbitrumStrategyTest {
  function _setUp() internal override {
    super._setUp();
    aToken = IAToken(0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5);
    asset = aToken.UNDERLYING_ASSET_ADDRESS();
    _setBalance(asset, address(vault), type(uint256).max);
  }
}

contract AaveV3ArbitrumWETHStrategyTest is AaveV3ArbitrumStrategyTest {
  function _setUp() internal override {
    super._setUp();
    aToken = IAToken(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8);
    asset = aToken.UNDERLYING_ASSET_ADDRESS();
    _setBalance(asset, address(vault), type(uint256).max);
  }
}
