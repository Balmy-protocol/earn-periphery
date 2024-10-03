// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {
  LiquidityMiningManager,
  ILiquidityMiningManager,
  StrategyId,
  IEarnStrategyRegistry,
  IEarnStrategy
} from "../../../src/liquidity-mining-manager/LiquidityMiningManager.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import { ERC20MintableBurnableMock } from "@balmy/earn-core-test/mocks/ERC20/ERC20MintableBurnableMock.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract LiquidityMiningManagerTest is PRBTest, StdCheats {
  event CampaignSet(StrategyId indexed strategyId, address indexed reward, uint256 emissionPerSecond, uint256 deadline);

  address private superAdmin = address(1);
  address private adminManageCampaigns = address(2);
  StrategyId private strategyId = StrategyId.wrap(1);
  IEarnStrategy private strategy = IEarnStrategy(address(3));
  IEarnStrategyRegistry private registry = IEarnStrategyRegistry(address(6));
  LiquidityMiningManager private manager;
  IERC20 private asset = IERC20(address(7));
  ERC20MintableBurnableMock private reward = new ERC20MintableBurnableMock();
  ERC20MintableBurnableMock private anotherReward = new ERC20MintableBurnableMock();

  function setUp() public virtual {
    manager = new LiquidityMiningManager(registry, superAdmin, CommonUtils.arrayOf(adminManageCampaigns));
    reward.mint(address(adminManageCampaigns), type(uint256).max);
    anotherReward.mint(address(adminManageCampaigns), type(uint256).max);
    vm.deal(address(adminManageCampaigns), type(uint256).max);

    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IEarnStrategyRegistry.getStrategy.selector, strategyId),
      abi.encode(address(strategy))
    );
    vm.mockCall(address(strategy), abi.encodeWithSelector(IEarnStrategy.asset.selector), abi.encode(address(asset)));
  }

  function test_constants() public {
    assertEq(manager.MANAGE_CAMPAIGNS_ROLE(), keccak256("MANAGE_CAMPAIGNS_ROLE"));
  }

  function test_constructor() public {
    assertEq(address(manager.STRATEGY_REGISTRY()), address(registry));

    assertTrue(manager.hasRole(manager.MANAGE_CAMPAIGNS_ROLE(), adminManageCampaigns));

    // Access control
    assertEq(manager.defaultAdminDelay(), 3 days);
    assertEq(manager.owner(), superAdmin);
    assertEq(manager.defaultAdmin(), superAdmin);
  }

  function test_strategySelfConfigure_emptyBytes() public {
    // Nothing happens
    manager.strategySelfConfigure("");
  }

  function test_setCampaign_firstCampaign() public {
    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    reward.approve(address(manager), balanceForCampaign);
    uint256 previousBalance = reward.balanceOf(address(adminManageCampaigns));
    vm.expectEmit();
    emit CampaignSet(strategyId, address(reward), 3, block.timestamp + 10);
    // Make sure it can be called without reverting
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });
    vm.stopPrank();
    assertEq(reward.balanceOf(address(adminManageCampaigns)), previousBalance - balanceForCampaign);
    assertEq(reward.balanceOf(address(manager)), balanceForCampaign);
    assertEq(manager.rewards(strategyId)[0], address(reward));
  }

  function test_setCampaign_twoCampaigns() public {
    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    reward.approve(address(manager), balanceForCampaign);
    anotherReward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    manager.setCampaign({
      strategyId: strategyId,
      reward: address(anotherReward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });
    vm.stopPrank();
    assertEq(manager.rewards(strategyId)[0], address(reward));
    assertEq(manager.rewards(strategyId)[1], address(anotherReward));
  }

  function test_setCampaign_modifyCampaign_addBalance() public {
    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    reward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    balanceForCampaign = 3 * 100 - balanceForCampaign;
    uint256 previousBalance = reward.balanceOf(address(adminManageCampaigns));
    reward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 100
    });
    vm.stopPrank();
    assertEq(reward.balanceOf(address(adminManageCampaigns)), previousBalance - balanceForCampaign);
    assertEq(reward.balanceOf(address(manager)), balanceForCampaign + 3 * 10);
  }

  function test_setCampaign_modifyCampaign_getBalance() public {
    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    reward.approve(address(manager), balanceForCampaign);

    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });
    uint256 previousBalance = reward.balanceOf(address(adminManageCampaigns));

    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 5
    });
    vm.stopPrank();
    assertEq(reward.balanceOf(address(adminManageCampaigns)), previousBalance + 3 * 5);
  }

  function test_setCampaign_firstCampaign_Native() public {
    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    uint256 previousBalance = address(adminManageCampaigns).balance;
    vm.expectEmit();
    emit CampaignSet(strategyId, Token.NATIVE_TOKEN, 3, block.timestamp + 10);
    // Make sure it can be called without reverting
    manager.setCampaign{ value: balanceForCampaign }({
      strategyId: strategyId,
      reward: Token.NATIVE_TOKEN,
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });
    vm.stopPrank();
    assertEq(address(adminManageCampaigns).balance, previousBalance - balanceForCampaign);
    assertEq(address(manager).balance, balanceForCampaign);
  }

  function test_setCampaign_modifyCampaign_addBalance_Native() public {
    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    manager.setCampaign{ value: balanceForCampaign }({
      strategyId: strategyId,
      reward: Token.NATIVE_TOKEN,
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    balanceForCampaign = 3 * 100 - balanceForCampaign;
    uint256 previousBalance = address(adminManageCampaigns).balance;
    manager.setCampaign{ value: balanceForCampaign }({
      strategyId: strategyId,
      reward: Token.NATIVE_TOKEN,
      emissionPerSecond: 3,
      deadline: block.timestamp + 100
    });
    vm.stopPrank();
    assertEq(address(adminManageCampaigns).balance, previousBalance - balanceForCampaign);
    assertEq(address(manager).balance, balanceForCampaign + 3 * 10);
  }

  function test_setCampaign_modifyCampaign_getBalance_Native() public {
    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;

    manager.setCampaign{ value: balanceForCampaign }({
      strategyId: strategyId,
      reward: Token.NATIVE_TOKEN,
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });
    uint256 previousBalance = address(adminManageCampaigns).balance;

    manager.setCampaign({
      strategyId: strategyId,
      reward: Token.NATIVE_TOKEN,
      emissionPerSecond: 3,
      deadline: block.timestamp + 5
    });
    vm.stopPrank();
    assertEq(address(adminManageCampaigns).balance, previousBalance + 3 * 5);
  }

  function test_setCampaign_RevertWhen_rewardIsStrategyAsset() public {
    vm.prank(adminManageCampaigns);
    vm.expectRevert(abi.encodeWithSelector(LiquidityMiningManager.InvalidReward.selector));
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(asset),
      emissionPerSecond: 3,
      deadline: block.timestamp + 1 days
    });
  }

  function test_setCampaign_RevertWhen_Native_InsufficientBalance() public {
    vm.prank(adminManageCampaigns);
    vm.expectRevert(abi.encodeWithSelector(LiquidityMiningManager.InsufficientBalance.selector));
    manager.setCampaign({
      strategyId: strategyId,
      reward: Token.NATIVE_TOKEN,
      emissionPerSecond: 3,
      deadline: block.timestamp + 1 days
    });
  }

  function test_rewardAmounts_twoCampaigns() public {
    uint256 timestamp = 10;
    vm.warp(timestamp);

    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    reward.approve(address(manager), balanceForCampaign);
    anotherReward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    assertEq(manager.rewardAmount(strategyId, address(reward)), 0); // No rewards yet

    timestamp += 5; // 5 seconds passed
    vm.warp(timestamp);

    assertEq(manager.rewardAmount(strategyId, address(reward)), 3 * 5);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(anotherReward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    assertEq(manager.rewardAmount(strategyId, address(anotherReward)), 0); // No rewards yet

    timestamp += 1000; // 1000 seconds passed, deadline reached for both campaigns
    vm.warp(timestamp);

    assertEq(manager.rewardAmount(strategyId, address(reward)), 3 * 10);
    assertEq(manager.rewardAmount(strategyId, address(anotherReward)), 3 * 10);
    vm.stopPrank();
  }

  function test_rewardAmount_modifyCampaign_addBalance() public {
    uint256 timestamp = 10; // Start at 10 seconds
    vm.warp(timestamp);

    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    reward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    timestamp += 5; // 5 seconds passed
    vm.warp(timestamp); // 5 seconds passed

    assertEq(manager.rewardAmount(strategyId, address(reward)), 3 * 5);
    balanceForCampaign = 10 * 100 - 3 * 5;
    reward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 10,
      deadline: block.timestamp + 100
    });

    assertEq(manager.rewardAmount(strategyId, address(reward)), 3 * 5);

    timestamp += 10;
    vm.warp(timestamp); // 10 seconds passed

    assertEq(manager.rewardAmount(strategyId, address(reward)), 3 * 5 + 10 * 10);

    balanceForCampaign = 5 * 100;
    reward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 5,
      deadline: block.timestamp + 100
    });

    timestamp += 15;
    vm.warp(timestamp); // 15 seconds passed
    assertEq(manager.rewardAmount(strategyId, address(reward)), 3 * 5 + 10 * 10 + 5 * 15);

    vm.stopPrank();
  }

  function test_claim() public {
    uint256 timestamp = 10; // Start at 10 seconds
    vm.warp(timestamp);

    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    reward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    timestamp += 1000; // 1000 seconds passed, deadline reached
    vm.warp(timestamp);

    assertEq(manager.rewardAmount(strategyId, address(reward)), 3 * 10);
    vm.stopPrank();

    uint256 previousBalance = reward.balanceOf(address(this));
    vm.startPrank(address(strategy));
    uint256 balance = manager.rewardAmount(strategyId, address(reward));
    manager.claim(strategyId, address(reward), balance / 2, address(this));
    assertEq(manager.rewardAmount(strategyId, address(reward)), balance / 2);
    assertEq(reward.balanceOf(address(this)), previousBalance + balance / 2);

    manager.claim(strategyId, address(reward), balance / 2, address(this));
    assertEq(reward.balanceOf(address(this)), previousBalance + balance);
    vm.stopPrank();
  }

  function test_claim_exact() public {
    uint256 timestamp = 10; // Start at 10 seconds
    vm.warp(timestamp);

    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    reward.approve(address(manager), balanceForCampaign);
    manager.setCampaign({
      strategyId: strategyId,
      reward: address(reward),
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    timestamp += 5; // 5 seconds passed
    vm.warp(timestamp);

    assertEq(manager.rewardAmount(strategyId, address(reward)), 3 * 5);
    vm.stopPrank();

    uint256 previousBalance = reward.balanceOf(address(this));
    uint256 balance = manager.rewardAmount(strategyId, address(reward));
    vm.prank(address(strategy));
    manager.claim(strategyId, address(reward), 3 * 5, address(this));
    assertEq(manager.rewardAmount(strategyId, address(reward)), 0);
    assertEq(reward.balanceOf(address(this)), previousBalance + 3 * 5);
  }

  function test_claim_Native() public {
    address recipient = address(89);

    uint256 timestamp = 10; // Start at 10 seconds
    vm.warp(timestamp);

    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    manager.setCampaign{ value: balanceForCampaign }({
      strategyId: strategyId,
      reward: Token.NATIVE_TOKEN,
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    timestamp += 1000; // 1000 seconds passed, deadline reached
    vm.warp(timestamp);

    assertEq(manager.rewardAmount(strategyId, Token.NATIVE_TOKEN), 3 * 10);
    vm.stopPrank();

    uint256 previousBalance = recipient.balance;
    vm.startPrank(address(strategy));
    uint256 balance = manager.rewardAmount(strategyId, Token.NATIVE_TOKEN);
    manager.claim(strategyId, Token.NATIVE_TOKEN, balance / 2, recipient);
    assertEq(manager.rewardAmount(strategyId, Token.NATIVE_TOKEN), balance / 2);
    assertEq(recipient.balance, previousBalance + balance / 2);

    manager.claim(strategyId, Token.NATIVE_TOKEN, balance / 2, recipient);
    assertEq(recipient.balance, previousBalance + balance);
    vm.stopPrank();
  }

  function test_claim_RevertWhen_InsufficientBalance() public {
    uint256 timestamp = 10; // Start at 10 seconds
    vm.warp(timestamp);

    vm.startPrank(adminManageCampaigns);
    uint256 balanceForCampaign = 3 * 10;
    manager.setCampaign{ value: balanceForCampaign }({
      strategyId: strategyId,
      reward: Token.NATIVE_TOKEN,
      emissionPerSecond: 3,
      deadline: block.timestamp + 10
    });

    timestamp += 5; // 5 seconds passed
    vm.warp(timestamp);

    vm.stopPrank();

    vm.startPrank(address(strategy));
    uint256 balance = manager.rewardAmount(strategyId, address(reward));
    vm.expectRevert(abi.encodeWithSelector(LiquidityMiningManager.InsufficientBalance.selector));
    manager.claim(strategyId, address(reward), balance + 1, address(this));
    vm.stopPrank();
  }

  function test_claim_RevertWhen_UnauthorizedCaller() public {
    uint256 balance = manager.rewardAmount(strategyId, address(reward));
    vm.expectRevert(abi.encodeWithSelector(LiquidityMiningManager.UnauthorizedCaller.selector));
    manager.claim(strategyId, address(reward), balance + 1, address(this));
  }
}
