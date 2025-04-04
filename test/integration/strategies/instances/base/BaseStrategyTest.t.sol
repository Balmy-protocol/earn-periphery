// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

import {
  EarnStrategyRegistry,
  IEarnStrategyRegistry,
  IEarnStrategy,
  StrategyId
} from "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";
import { IEarnVault } from "@balmy/earn-core/vault/EarnVault.sol";
import { IGlobalEarnRegistry } from "src/global-registry/GlobalEarnRegistry.sol";
import { IFeeManager } from "src/interfaces/IFeeManager.sol";
import { IValidationManagersRegistryCore } from "src/interfaces/IValidationManagersRegistry.sol";
import { IGuardianManager, IGuardianManagerCore } from "src/interfaces/IGuardianManager.sol";
import { IDelayedWithdrawalManager } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { GuardianManager } from "src/strategies/layers/guardian/external/GuardianManager.sol";
import { MorphoRewardsManager } from "src/strategies/layers/connector/morpho/MorphoRewardsManager.sol";
import { CometRewardsTracker } from "src/strategies/layers/connector/compound-v3/CometRewardsTracker.sol";

import {
  ILiquidityMiningManager,
  ILiquidityMiningManagerCore,
  LiquidityMiningManager
} from "src/strategies/layers/liquidity-mining/external/LiquidityMiningManager.sol";
import { FeeManager } from "src/strategies/layers/fees/external/FeeManager.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";
import { Fees } from "src/types/Fees.sol";
import { ICreationValidationManagerCore } from "src/interfaces/ICreationValidationManager.sol";
import { BaseStrategy } from "../interface/BaseStrategy.sol";

abstract contract BaseStrategyTest is PRBTest, StdUtils, StdCheats {
  using SafeERC20 for IERC20;
  using Token for address;

  BaseStrategy internal _strategy;
  StrategyId internal strategyId;
  BaseStrategy internal migrateStrategy;
  StrategyId internal migrateStrategyId;

  address internal owner = address(2);
  address internal guardian = address(23);
  address internal judge = address(24);

  IEarnVault internal vault = IEarnVault(address(3));
  IGlobalEarnRegistry internal globalRegistry = IGlobalEarnRegistry(address(4));
  IEarnStrategyRegistry internal strategyRegistry;

  IFeeManager internal feeManager = IFeeManager(address(7));
  IValidationManagersRegistryCore internal validationManagerRegistry = IValidationManagersRegistryCore(address(9));
  IGuardianManager internal guardianManager;
  ILiquidityMiningManager internal liquidityMiningManager;
  IDelayedWithdrawalManager internal delayedWithdrawalManager = IDelayedWithdrawalManager(address(12));
  MorphoRewardsManager internal morphoRewardsManager = new MorphoRewardsManager(owner, CommonUtils.arrayOf(owner));
  ICreationValidationManagerCore[] internal creationValidationManager;

  bytes internal validationManagersStrategyData = abi.encodePacked("registryData");
  bytes internal validationData = abi.encode(validationManagersStrategyData, new bytes[](0));
  bytes internal guardianData = abi.encodePacked("guardianData");
  bytes internal feesData = abi.encode(Fees(0, 0, 0, 0));
  bytes internal liquidityMiningData = abi.encodePacked("liquidityMiningData");

  function setUp() public {
    _configureFork();
    _setUp();
    strategyRegistry = new EarnStrategyRegistry();
    liquidityMiningManager =
      new LiquidityMiningManager(IEarnStrategyRegistry(address(strategyRegistry)), owner, CommonUtils.arrayOf(owner));
    guardianManager = new GuardianManager(
      IEarnStrategyRegistry(address(strategyRegistry)),
      owner,
      CommonUtils.arrayOf(owner, guardian),
      CommonUtils.arrayOf(owner, judge),
      CommonUtils.arrayOf(owner, guardian),
      CommonUtils.arrayOf(owner, judge)
    );

    feeManager = new FeeManager(
      IEarnStrategyRegistry(address(strategyRegistry)),
      owner,
      CommonUtils.arrayOf(owner),
      CommonUtils.arrayOf(owner),
      Fees(0, 0, 0, 0)
    );

    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.STRATEGY_REGISTRY.selector),
      abi.encode(address(strategyRegistry))
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("COMET_REWARDS_TRACKER")),
      abi.encode(new CometRewardsTracker())
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("FEE_MANAGER")),
      abi.encode(feeManager)
    );

    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("GUARDIAN_MANAGER")),
      abi.encode(guardianManager)
    );
    vm.mockCall(
      address(guardianManager), abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector), ""
    );
    vm.mockCall(
      address(liquidityMiningManager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector),
      ""
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("LIQUIDITY_MINING_MANAGER")),
      abi.encode(liquidityMiningManager)
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("VALIDATION_MANAGERS_REGISTRY")),
      abi.encode(validationManagerRegistry)
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("MORPHO_REWARDS_MANAGER")),
      abi.encode(morphoRewardsManager)
    );
    vm.mockCall(
      address(validationManagerRegistry),
      abi.encodeWithSelector(IValidationManagersRegistryCore.strategySelfConfigure.selector),
      abi.encode(new ICreationValidationManagerCore[](0))
    );
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.STRATEGY_REGISTRY.selector),
      abi.encode(address(strategyRegistry))
    );
    (IEarnStrategy __strategy, StrategyId _strategyId) = _deployNewStrategy();
    _strategy = BaseStrategy(payable(address(__strategy)));
    strategyId = _strategyId;
    (IEarnStrategy __migrateStrategy,) = _deployNewStrategyToMigrate(strategyId);
    migrateStrategy = BaseStrategy(payable(address(__migrateStrategy)));

    vm.makePersistent(address(__strategy));
    vm.makePersistent(address(strategyRegistry));
    vm.makePersistent(address(migrateStrategy));
    vm.makePersistent(address(morphoRewardsManager));
  }

  receive() external payable { }
  // solhint-disable no-empty-blocks
  function _setUp() internal virtual;

  // solhint-disable no-empty-blocks
  function _configureFork() internal virtual;

  // solhint-disable no-empty-blocks
  function _deployNewStrategy() internal virtual returns (IEarnStrategy, StrategyId);

  // solhint-disable no-empty-blocks
  function _deployNewStrategyToMigrate(StrategyId _strategyId) internal virtual returns (IEarnStrategy, StrategyId) { }

  function _balance(address asset, address account) internal view returns (uint256) {
    return asset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE ? account.balance : IERC20(asset).balanceOf(account);
  }

  function _maxApproval(address asset, address spender) internal virtual {
    if (asset != Token.NATIVE_TOKEN) {
      IERC20(asset).approve(spender, type(uint256).max);
    }
  }

  function _setBalance(address asset, address account, uint256 amount) internal virtual {
    if (asset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      deal(account, amount);
    } else {
      deal(asset, account, amount);
    }
  }

  function _setBalance(address asset, address account, uint256 amount, address from) internal virtual {
    // We need to set the balance of the account to 0
    uint256 balance = IERC20(asset).balanceOf(account);
    if (balance > amount) {
      vm.prank(from);
      IERC20(asset).transfer(account, balance - amount);
    } else if (balance < amount) {
      vm.prank(from);
      IERC20(asset).transfer(account, amount - balance);
    }
  }

  function _give(address asset, address account, uint256 amount) internal returns (uint256 newBalance) {
    uint256 balance = _balance(asset, account);
    _setBalance(asset, account, balance + amount);
    return balance + amount;
  }

  // solhint-disable no-empty-blocks
  function _generateYield() internal virtual { }

  function _maxDepositAmount() internal pure virtual returns (uint256) {
    return type(uint80).max;
  }

  function _warpTime(uint256 secondsToWarp) internal virtual {
    vm.warp(block.timestamp + secondsToWarp);
  }

  function applyRescueFee(uint256 amount) internal view returns (uint256) {
    Fees memory fees = feeManager.getFees(strategyId);
    return amount - amount * fees.rescueFee / 10_000;
  }

  function assertAlmostEqArrays(uint256[] memory a, uint256[] memory b, uint256 precision) internal {
    for (uint256 i = 0; i < a.length; i++) {
      assertAlmostEq(a[i], b[i], precision);
    }
  }
}
