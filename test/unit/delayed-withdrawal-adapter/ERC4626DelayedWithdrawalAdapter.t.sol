// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { ERC4626DelayedWithdrawalAdapter } from "src/delayed-withdrawal-adapter/ERC4626DelayedWithdrawalAdapter.sol";

import {
  IDelayedWithdrawalManager,
  DelayedWithdrawalManager
} from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { LiquidityMiningManager } from "src/liquidity-mining-manager/LiquidityMiningManager.sol";

import { EarnVault, IEarnVault, StrategyId, IEarnNFTDescriptor } from "@balmy/earn-core/vault/EarnVault.sol";
import {
  EarnStrategyRegistry, IEarnStrategyRegistry
} from "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";
import { CommonUtils } from "../../utils/CommonUtils.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { IEarnBalmyStrategy } from "src/interfaces/IEarnBalmyStrategy.sol";
import { PermissionUtils } from "@balmy/nft-permissions-test/PermissionUtils.sol";
import { GlobalEarnRegistry } from "src/global-registry/GlobalEarnRegistry.sol";
import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ERC4626DelayedStrategyMock } from "../../mocks/strategies/ERC4626DelayedStrategyMock.sol";
import { FeeManager, Fees } from "src/fee-manager/FeeManager.sol";
import { TOSManager } from "src/tos-manager/TOSManager.sol";

contract ERC4626DelayedWithdrawalAdapterTest is PRBTest {
  // solhint-disable-next-line const-name-snakecase
  address internal constant _FARM_TOKEN = 0x305F25377d0a39091e99B975558b1bdfC3975654;
  // solhint-disable-next-line const-name-snakecase
  address internal constant _FARM_TOKEN_HOLDER = 0x18451C199Dea9563DE64A87b43045b0554E05ECD;

  using SafeERC20 for IERC20;

  address private owner = address(this);
  ERC4626DelayedWithdrawalAdapter private erc4626DelayedWithdrawalAdapter;
  IEarnVault private vault;
  address[] private tokens = new address[](1);
  IEarnBalmyStrategy private strategy;
  StrategyId private strategyId;
  GlobalEarnRegistry private globalRegistry;
  uint256 private position;

  bytes32 public constant DELAYED_WITHDRAWAL_MANAGER = keccak256("DELAYED_WITHDRAWAL_MANAGER");
  bytes32 public constant LIQUIDITY_MINING_MANAGER = keccak256("LIQUIDITY_MINING_MANAGER");
  bytes32 public constant FEE_MANAGER = keccak256("FEE_MANAGER");
  bytes32 public constant TOS_MANAGER = keccak256("TOS_MANAGER");

  function setUp() public virtual {
    uint256 polygonFork = vm.createFork(vm.rpcUrl("polygon"));
    vm.selectFork(polygonFork);
    vm.rollFork(63_000_000);

    globalRegistry = new GlobalEarnRegistry(address(this));

    IEarnStrategyRegistry strategyRegistry = new EarnStrategyRegistry();
    IEarnNFTDescriptor nftDescriptor = IEarnNFTDescriptor(address(this));
    vault = new EarnVault(strategyRegistry, address(this), CommonUtils.arrayOf(address(this)), nftDescriptor);
    uint104 amountToDeposit1 = 100_000;

    tokens[0] = IERC4626(_FARM_TOKEN).asset();

    globalRegistry.setAddress(DELAYED_WITHDRAWAL_MANAGER, address(new DelayedWithdrawalManager(vault)));
    erc4626DelayedWithdrawalAdapter = new ERC4626DelayedWithdrawalAdapter(globalRegistry, _FARM_TOKEN, 100);

    strategy = new ERC4626DelayedStrategyMock(
      vault, IERC4626(_FARM_TOKEN), "ERC4626DelayedStrategy", erc4626DelayedWithdrawalAdapter
    );
    strategyId = strategyRegistry.registerStrategy(owner, strategy);

    vm.mockCall(
      address(vault), abi.encodeWithSelector(vault.positionsStrategy.selector, position), abi.encode(strategyId)
    );
  }

  function testFork_estimatedPendingFunds_AreZeroWithoutInitiatedWithdraw() public {
    uint256 pendingAmount = erc4626DelayedWithdrawalAdapter.estimatedPendingFunds(position, owner);
    assertEq(pendingAmount, 0);
  }

  function testFork_withdrawableFunds_AreZeroWithoutInitiatedWithdraw() public {
    uint256 pendingAmount = erc4626DelayedWithdrawalAdapter.estimatedPendingFunds(position, owner);
    assertEq(pendingAmount, 0);
  }

  function testFork_initiateDelayedWithdrawal() public {
    uint256 amount = 1000;
    uint256 amountToTransfer = IERC4626(_FARM_TOKEN).previewWithdraw(uint256(amount));
    vm.prank(_FARM_TOKEN_HOLDER);
    IERC20(_FARM_TOKEN).transfer(address(erc4626DelayedWithdrawalAdapter), amountToTransfer);
    vm.startPrank(address(strategy));

    erc4626DelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, owner, amountToTransfer);
    uint256 pendingAmount = erc4626DelayedWithdrawalAdapter.estimatedPendingFunds(position, owner);
    assertAlmostEq(pendingAmount, amount, 2);

    vm.stopPrank();
  }

  function testFork_withdraw() public {
    uint256 amount = 1000;

    // Send farmToken to the adapter, and initiate a withdrawal with this balance
    uint256 amountToTransfer = IERC4626(_FARM_TOKEN).previewWithdraw(uint256(amount));
    vm.prank(_FARM_TOKEN_HOLDER);
    IERC20(_FARM_TOKEN).transfer(address(erc4626DelayedWithdrawalAdapter), amountToTransfer);

    vm.startPrank(address(strategy));
    erc4626DelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, owner, amountToTransfer);

    // Force the delayed to be finalized
    vm.warp(block.timestamp + 100);

    uint256 withdrawableFunds = erc4626DelayedWithdrawalAdapter.withdrawableFunds(position, owner);
    assertNotEq(withdrawableFunds, 0);
    vm.startPrank(address(erc4626DelayedWithdrawalAdapter.manager()));
    erc4626DelayedWithdrawalAdapter.withdraw(position, IERC4626(_FARM_TOKEN).asset(), address(strategy));
    uint256 pendingAmount = erc4626DelayedWithdrawalAdapter.estimatedPendingFunds(position, owner);
    uint256 strategyBalance = IERC20(IERC4626(_FARM_TOKEN).asset()).balanceOf(address(strategy));
    assertAlmostEq(withdrawableFunds, strategyBalance, 1);
    assertEq(pendingAmount, 0);

    withdrawableFunds = erc4626DelayedWithdrawalAdapter.withdrawableFunds(position, owner);
    assertEq(withdrawableFunds, 0);

    vm.stopPrank();
  }

  function testFork_withdraw_multiple() public {
    uint256 amount = 1000;

    // Send farmToken to the adapter, and initiate a withdrawal with this balance
    uint256 amountToTransfer = IERC4626(_FARM_TOKEN).previewWithdraw(uint256(amount));
    vm.prank(_FARM_TOKEN_HOLDER);
    IERC20(_FARM_TOKEN).transfer(address(erc4626DelayedWithdrawalAdapter), amountToTransfer);

    vm.startPrank(address(strategy));

    erc4626DelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, owner, amountToTransfer / 2);
    erc4626DelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, owner, amountToTransfer / 2);

    // Force the delayed to be finalized
    vm.warp(block.timestamp + 100);

    uint256 withdrawableFunds = erc4626DelayedWithdrawalAdapter.withdrawableFunds(position, owner);
    assertNotEq(withdrawableFunds, 0);
    vm.startPrank(address(erc4626DelayedWithdrawalAdapter.manager()));
    erc4626DelayedWithdrawalAdapter.withdraw(position, IERC4626(_FARM_TOKEN).asset(), address(strategy));
    uint256 pendingAmount = erc4626DelayedWithdrawalAdapter.estimatedPendingFunds(position, owner);
    uint256 strategyBalance = IERC20(IERC4626(_FARM_TOKEN).asset()).balanceOf(address(strategy));
    assertAlmostEq(withdrawableFunds, strategyBalance, 1);
    assertEq(pendingAmount, 0);
    vm.stopPrank();
  }
}
