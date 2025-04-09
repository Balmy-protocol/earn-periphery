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
import { IEarnVault, EarnVault } from "@balmy/earn-core/vault/EarnVault.sol";
import { EarnNFTDescriptor } from "@balmy/earn-core/nft-descriptor/EarnNFTDescriptor.sol";
import { IGlobalEarnRegistry, GlobalEarnRegistry } from "src/global-registry/GlobalEarnRegistry.sol";
import { IFeeManager } from "src/interfaces/IFeeManager.sol";
import { IValidationManagersRegistryCore } from "src/interfaces/IValidationManagersRegistry.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianManager } from "src/strategies/layers/guardian/external/GuardianManager.sol";
import { MorphoRewardsManager } from "src/strategies/layers/connector/morpho/MorphoRewardsManager.sol";
import { CometRewardsTracker } from "src/strategies/layers/connector/compound-v3/CometRewardsTracker.sol";
import { GlobalValidationManagersRegistry } from
  "src/strategies/layers/creation-validation/external/GlobalValidationManagersRegistry.sol";

import {
  ILiquidityMiningManager,
  LiquidityMiningManager
} from "src/strategies/layers/liquidity-mining/external/LiquidityMiningManager.sol";
import { FeeManager } from "src/strategies/layers/fees/external/FeeManager.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";
import { Fees } from "src/types/Fees.sol";
import { ICreationValidationManagerCore } from "src/interfaces/ICreationValidationManager.sol";
import { BaseStrategy } from "../interface/BaseStrategy.sol";
import { INFTPermissions } from "@balmy/nft-permissions/interfaces/INFTPermissions.sol";

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

  IEarnVault internal vault;
  IGlobalEarnRegistry internal globalRegistry;
  IEarnStrategyRegistry internal strategyRegistry;

  IFeeManager internal feeManager;
  IValidationManagersRegistryCore internal validationManagerRegistry;
  IGuardianManager internal guardianManager;
  ILiquidityMiningManager internal liquidityMiningManager;
  MorphoRewardsManager internal morphoRewardsManager = new MorphoRewardsManager(owner, CommonUtils.arrayOf(owner));
  ICreationValidationManagerCore[] internal creationValidationManager;

  bytes internal validationManagersStrategyData = abi.encodePacked("registryData");
  bytes internal validationData = abi.encode(validationManagersStrategyData, new bytes[](0));
  bytes internal guardianData = "";
  bytes internal feesData = abi.encode(Fees(0, 0, 0, 0));
  bytes internal liquidityMiningData = "";

  INFTPermissions.PermissionSet[] internal permissions;

  address internal asset;
  address internal lmmToken;

  function setUp() public {
    _configureFork();
    _setUp();
    strategyRegistry = new EarnStrategyRegistry();
    vault = new EarnVault(strategyRegistry, owner, CommonUtils.arrayOf(owner), new EarnNFTDescriptor("baseUrl/", owner));
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
    ICreationValidationManagerCore[] memory creationValidationManagers = new ICreationValidationManagerCore[](0);
    validationManagerRegistry = new GlobalValidationManagersRegistry(creationValidationManagers, owner);
    feeManager = new FeeManager(
      IEarnStrategyRegistry(address(strategyRegistry)),
      owner,
      CommonUtils.arrayOf(owner),
      CommonUtils.arrayOf(owner),
      Fees(0, 0, 0, 0)
    );
    GlobalEarnRegistry.InitialConfig[] memory initialConfig = new GlobalEarnRegistry.InitialConfig[](6);
    initialConfig[0] =
      GlobalEarnRegistry.InitialConfig({ id: keccak256("FEE_MANAGER"), contractAddress: address(feeManager) });
    initialConfig[1] = GlobalEarnRegistry.InitialConfig({
      id: keccak256("VALIDATION_MANAGERS_REGISTRY"),
      contractAddress: address(validationManagerRegistry)
    });
    initialConfig[2] = GlobalEarnRegistry.InitialConfig({
      id: keccak256("LIQUIDITY_MINING_MANAGER"),
      contractAddress: address(liquidityMiningManager)
    });
    initialConfig[3] =
      GlobalEarnRegistry.InitialConfig({ id: keccak256("GUARDIAN_MANAGER"), contractAddress: address(guardianManager) });
    initialConfig[4] = GlobalEarnRegistry.InitialConfig({
      id: keccak256("MORPHO_REWARDS_MANAGER"),
      contractAddress: address(morphoRewardsManager)
    });
    initialConfig[5] = GlobalEarnRegistry.InitialConfig({
      id: keccak256("COMET_REWARDS_TRACKER"),
      contractAddress: address(new CometRewardsTracker())
    });
    permissions = new INFTPermissions.PermissionSet[](0);

    globalRegistry = new GlobalEarnRegistry(initialConfig, owner);

    (IEarnStrategy __strategy, StrategyId _strategyId) = _deployNewStrategy();
    _strategy = BaseStrategy(payable(address(__strategy)));
    strategyId = _strategyId;
    (IEarnStrategy __migrateStrategy,) = _deployNewStrategyToMigrate(strategyId);
    migrateStrategy = BaseStrategy(payable(address(__migrateStrategy)));

    vm.makePersistent(address(__strategy));
    vm.makePersistent(address(strategyRegistry));
    vm.makePersistent(address(migrateStrategy));
    vm.makePersistent(address(morphoRewardsManager));
    vm.makePersistent(address(vault));
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

  function _balance(address _asset, address account) internal view returns (uint256) {
    return _asset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE ? account.balance : IERC20(_asset).balanceOf(account);
  }

  function _maxApproval(address _asset, address spender) internal virtual {
    if (_asset != Token.NATIVE_TOKEN) {
      IERC20(_asset).approve(spender, type(uint256).max);
    }
  }

  function _setBalance(address _asset, address account, uint256 amount) internal virtual {
    if (_asset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      deal(account, amount);
    } else {
      deal(_asset, account, amount);
    }
  }

  function _setBalance(address _asset, address account, uint256 amount, address from) internal virtual {
    // We need to set the balance of the account to 0
    uint256 balance = IERC20(_asset).balanceOf(account);
    if (balance > amount) {
      vm.prank(from);
      IERC20(_asset).transfer(account, balance - amount);
    } else if (balance < amount) {
      vm.prank(from);
      IERC20(_asset).transfer(account, amount - balance);
    }
  }

  function _give(address _asset, address account, uint256 amount) internal returns (uint256 newBalance) {
    uint256 balance = _balance(_asset, account);
    _setBalance(_asset, account, balance + amount);
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
