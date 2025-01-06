// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { LidoSTETHDelayedWithdrawalAdapter } from
  "src/strategies/layers/connector/lido/LidoSTETHDelayedWithdrawalAdapter.sol";
import {
  IDelayedWithdrawalManager,
  DelayedWithdrawalManager
} from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";

import { EarnVault, IEarnVault, StrategyId, IEarnNFTDescriptor } from "@balmy/earn-core/vault/EarnVault.sol";
import {
  EarnStrategyRegistry, IEarnStrategyRegistry
} from "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { PermissionUtils } from "@balmy/nft-permissions-test/PermissionUtils.sol";
import { LidoSTETHStrategyMock } from "test/mocks/strategies/LidoSTETHStrategyMock.sol";
import { GlobalEarnRegistry } from "src/global-registry/GlobalEarnRegistry.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { LidoSTETHQueueMock } from "./mocks/ILidoSTETHQueueMock.sol";

contract LidoSTETHDelayedWithdrawalAdapterTest is PRBTest {
  // solhint-disable-next-line const-name-snakecase
  address internal constant _stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84; // stETH
  // solhint-disable-next-line const-name-snakecase
  address internal constant stETH_TOKEN_HOLDER = 0x93c4b944D05dfe6df7645A86cd2206016c51564D; // stETH Token Holder

  using SafeERC20 for IERC20;

  address private owner = address(this);
  LidoSTETHDelayedWithdrawalAdapter private lidoSTETHDelayedWithdrawalAdapter;
  IEarnVault private vault;
  address[] private tokens = new address[](1);
  LidoSTETHStrategyMock private strategy;
  StrategyId private strategyId;
  IDelayedWithdrawalManager private delayedWithdrawalManager;
  GlobalEarnRegistry private globalRegistry;
  LidoSTETHQueueMock private queue;
  uint256 private position;

  bytes32 public constant DELAYED_WITHDRAWAL_MANAGER = keccak256("DELAYED_WITHDRAWAL_MANAGER");

  function setUp() public virtual {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);

    queue = new LidoSTETHQueueMock();

    globalRegistry = new GlobalEarnRegistry(new GlobalEarnRegistry.InitialConfig[](0), address(this));

    IEarnStrategyRegistry strategyRegistry = new EarnStrategyRegistry();
    IEarnNFTDescriptor nftDescriptor = IEarnNFTDescriptor(address(this));
    vault = new EarnVault(strategyRegistry, address(this), CommonUtils.arrayOf(address(this)), nftDescriptor);
    uint104 amountToDeposit1 = 1_000_000;
    vm.deal(address(this), uint256(amountToDeposit1));
    vm.deal(address(queue), uint256(amountToDeposit1));

    tokens[0] = Token.NATIVE_TOKEN; // ETH

    globalRegistry.setAddress(DELAYED_WITHDRAWAL_MANAGER, address(new DelayedWithdrawalManager(vault)));
    lidoSTETHDelayedWithdrawalAdapter = new LidoSTETHDelayedWithdrawalAdapter(globalRegistry, queue);

    strategy = new LidoSTETHStrategyMock(vault, lidoSTETHDelayedWithdrawalAdapter);
    strategyId = strategy.registerStrategy(owner);

    (position,) = vault.createPosition{ value: amountToDeposit1 }(
      strategyId, tokens[0], amountToDeposit1, owner, PermissionUtils.buildEmptyPermissionSet(), "", ""
    );

    vm.prank(stETH_TOKEN_HOLDER);
    IERC20(_stETH).transfer(address(strategy), uint256(amountToDeposit1));

    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(vault.positionsStrategy.selector, position),
      abi.encode(strategyId, strategy)
    );
  }

  function testFork_estimatedPendingFunds_AreZeroWithoutInitiatedWithdraw() public {
    uint256 pendingAmount = lidoSTETHDelayedWithdrawalAdapter.estimatedPendingFunds(position, Token.NATIVE_TOKEN);
    assertEq(pendingAmount, 0);
  }

  function testFork_withdrawableFunds_AreZeroWithoutInitiatedWithdraw() public {
    uint256 pendingAmount = lidoSTETHDelayedWithdrawalAdapter.estimatedPendingFunds(position, Token.NATIVE_TOKEN);
    assertEq(pendingAmount, 0);
  }

  function testFork_initiateDelayedWithdrawal_RevertWhen_tokenIsNotETH() public {
    vm.expectRevert(LidoSTETHDelayedWithdrawalAdapter.TokenNotETH.selector);
    lidoSTETHDelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, address(1), 1000);
  }

  function testFork_initiateDelayedWithdrawal() public {
    uint256 amount = 1000;
    vm.prank(stETH_TOKEN_HOLDER);
    IERC20(_stETH).transfer(address(lidoSTETHDelayedWithdrawalAdapter), uint256(amount));
    vm.startPrank(address(strategy));

    lidoSTETHDelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, Token.NATIVE_TOKEN, amount);
    // Make sure that the adapter doesn't have any funds for other tokens
    uint256 pendingAmount = lidoSTETHDelayedWithdrawalAdapter.estimatedPendingFunds(position, Token.NATIVE_TOKEN);
    assertAlmostEq(pendingAmount, amount, 2);
    assertEq(lidoSTETHDelayedWithdrawalAdapter.estimatedPendingFunds(position, address(1)), 0);

    vm.stopPrank();
  }

  function testFork_withdraw_RevertWhen_tokenIsNotETH() public {
    vm.prank(address(lidoSTETHDelayedWithdrawalAdapter.manager()));
    vm.expectRevert(LidoSTETHDelayedWithdrawalAdapter.TokenNotETH.selector);
    lidoSTETHDelayedWithdrawalAdapter.withdraw(position, address(1), address(strategy));
  }

  function testFork_withdraw() public {
    uint256 amount = 1000;

    // Send stETH to the adapter, and initiate a withdrawal with this balance
    vm.prank(stETH_TOKEN_HOLDER);
    IERC20(_stETH).transfer(address(lidoSTETHDelayedWithdrawalAdapter), uint256(amount));

    vm.startPrank(address(strategy));
    lidoSTETHDelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, Token.NATIVE_TOKEN, amount);

    // Force the delayed to be finalized
    queue.setTimeToWithdraw(true);

    uint256 withdrawableFunds = lidoSTETHDelayedWithdrawalAdapter.withdrawableFunds(position, Token.NATIVE_TOKEN);
    assertNotEq(withdrawableFunds, 0);
    // Make sure that the adapter doesn't have any funds for other tokens
    assertEq(lidoSTETHDelayedWithdrawalAdapter.withdrawableFunds(position, address(1)), 0);
    vm.startPrank(address(lidoSTETHDelayedWithdrawalAdapter.manager()));
    lidoSTETHDelayedWithdrawalAdapter.withdraw(position, Token.NATIVE_TOKEN, address(strategy));
    uint256 pendingAmount = lidoSTETHDelayedWithdrawalAdapter.estimatedPendingFunds(position, Token.NATIVE_TOKEN);

    assertAlmostEq(withdrawableFunds, address(strategy).balance, 1);
    assertEq(pendingAmount, 0);

    withdrawableFunds = lidoSTETHDelayedWithdrawalAdapter.withdrawableFunds(position, Token.NATIVE_TOKEN);
    assertEq(withdrawableFunds, 0);

    vm.stopPrank();
  }

  function testFork_withdraw_multiple() public {
    uint256 amount = 1000;

    // Send stETH to the adapter, and initiate a withdrawal with this balance
    vm.prank(stETH_TOKEN_HOLDER);
    IERC20(_stETH).transfer(address(lidoSTETHDelayedWithdrawalAdapter), uint256(amount));

    vm.startPrank(address(strategy));

    lidoSTETHDelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, Token.NATIVE_TOKEN, amount / 2);
    lidoSTETHDelayedWithdrawalAdapter.initiateDelayedWithdrawal(position, Token.NATIVE_TOKEN, amount / 2);

    // Force the delayed to be finalized
    queue.setTimeToWithdraw(true);

    uint256 withdrawableFunds = lidoSTETHDelayedWithdrawalAdapter.withdrawableFunds(position, Token.NATIVE_TOKEN);
    assertNotEq(withdrawableFunds, 0);
    vm.startPrank(address(lidoSTETHDelayedWithdrawalAdapter.manager()));
    lidoSTETHDelayedWithdrawalAdapter.withdraw(position, Token.NATIVE_TOKEN, address(strategy));
    uint256 pendingAmount = lidoSTETHDelayedWithdrawalAdapter.estimatedPendingFunds(position, Token.NATIVE_TOKEN);

    assertAlmostEq(withdrawableFunds, address(strategy).balance, 1);
    assertEq(pendingAmount, 0);
    queue.setTimeToWithdraw(false);
    vm.stopPrank();
  }
}
