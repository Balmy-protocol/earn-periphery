// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import {
  SpecialWithdrawalCode,
  IGuardianManagerCore,
  ExternalGuardian,
  IGlobalEarnRegistry,
  StrategyId,
  IEarnStrategy
} from "src/strategies/guardian/ExternalGuardian.sol";
import { CommonUtils } from "../../../utils/CommonUtils.sol";

contract ExternalGuardianTest is Test {
  ExternalGuardianInstance private guardian;
  IGlobalEarnRegistry private registry = IGlobalEarnRegistry(address(1));
  IGuardianManagerCore private manager = IGuardianManagerCore(address(2));
  address private asset = address(3);
  address private reward = address(4);
  StrategyId private strategyId = StrategyId.wrap(1);

  function setUp() public virtual {
    guardian = new ExternalGuardianInstance(registry, strategyId, CommonUtils.arrayOf(asset, reward));
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("GUARDIAN_MANAGER")),
      abi.encode(manager)
    );
    vm.mockCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector), "");
    vm.mockCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.startRescue.selector), "");
    vm.mockCall(address(asset), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(address(reward), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
  }

  function test_init() public {
    bytes memory data = "1234567";
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, data));
    guardian.init(data);
    assertTrue(guardian.rescueStatus() == ExternalGuardian.RescueStatus.OK);
  }

  function test_rescue_ok() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.OK);
    address feeRecipient = address(10);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canStartRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectCall(
      address(manager), abi.encodeWithSelector(IGuardianManagerCore.startRescue.selector, strategyId, feeRecipient)
    );
    (address[] memory tokens, uint256[] memory withdrawn) = guardian.rescue(feeRecipient);

    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawn, CommonUtils.arrayOf(10_000, 20_000));

    ExternalGuardianInstance.Withdrawal memory withdrawal = guardian.withdrawal();
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(10_000, 20_000));
    assertEq(withdrawal.recipient, address(guardian));
    assertTrue(guardian.rescueStatus() == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
  }

  function test_rescue_okWithBalances() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.OK_WITH_BALANCE_ON_STRATEGY);
    address feeRecipient = address(10);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canStartRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectCall(
      address(manager), abi.encodeWithSelector(IGuardianManagerCore.startRescue.selector, strategyId, feeRecipient)
    );
    (address[] memory tokens, uint256[] memory withdrawn) = guardian.rescue(feeRecipient);

    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawn, CommonUtils.arrayOf(10_000, 20_000));

    ExternalGuardianInstance.Withdrawal memory withdrawal = guardian.withdrawal();
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(10_000, 20_000));
    assertEq(withdrawal.recipient, address(guardian));
    assertTrue(guardian.rescueStatus() == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
  }

  function test_rescue_rescueNeedsConfirmation() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    address feeRecipient = address(10);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canStartRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.startRescue.selector), 0);
    (address[] memory tokens, uint256[] memory withdrawn) = guardian.rescue(feeRecipient);

    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawn, CommonUtils.arrayOf(10_000, 20_000));

    ExternalGuardianInstance.Withdrawal memory withdrawal = guardian.withdrawal();
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(10_000, 20_000));
    assertEq(withdrawal.recipient, address(guardian));
    assertTrue(guardian.rescueStatus() == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
  }

  function test_rescue_revertWhen_alreadyRescued() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUED);
    address feeRecipient = address(10);

    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    guardian.rescue(feeRecipient);
  }

  function test_rescue_revertWhen_callerCantRescue() public {
    address feeRecipient = address(10);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canStartRescue.selector, strategyId, address(this)),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.CallerCantPerformAction.selector));
    guardian.rescue(feeRecipient);
  }

  function test_rescue_revertWhen_withdrawalTypeIsNotImmediate() public {
    guardian.setWithdrawalType(IEarnStrategy.WithdrawalType.DELAYED);
    address feeRecipient = address(10);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canStartRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.OnlyImmediateWithdrawalsSupported.selector));
    guardian.rescue(feeRecipient);
  }

  function test_cancelRescue() public {
    uint256 balance = 12_345_678;
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    vm.mockCall(
      address(asset), abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)), abi.encode(balance)
    );
    vm.mockCall(address(reward), abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)), abi.encode(0));
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canCancelRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.cancelRescue.selector, strategyId));
    guardian.cancelRescue();

    ExternalGuardianInstance.Deposit memory deposit = guardian.deposit();
    assertEq(deposit.token, asset);
    assertEq(deposit.amount, balance);
    assertTrue(guardian.rescueStatus() == ExternalGuardian.RescueStatus.OK);
  }

  function test_cancelRescue_withBalances() public {
    uint256 assetBalance = 12_345_678;
    uint256 rewardBalance = 987_655;
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    vm.mockCall(
      address(asset), abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)), abi.encode(assetBalance)
    );
    vm.mockCall(
      address(reward), abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)), abi.encode(rewardBalance)
    );
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canCancelRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.cancelRescue.selector, strategyId));
    guardian.cancelRescue();

    ExternalGuardianInstance.Deposit memory deposit = guardian.deposit();
    assertEq(deposit.token, asset);
    assertEq(deposit.amount, assetBalance);
    assertTrue(guardian.rescueStatus() == ExternalGuardian.RescueStatus.OK_WITH_BALANCE_ON_STRATEGY);
  }

  function test_cancelRescue_revertWhen_noNeedForConfirmation() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.OK);

    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    guardian.cancelRescue();
  }

  function test_cancelRescue_revertWhen_callerCantCancelRescue() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canCancelRescue.selector, strategyId, address(this)),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.CallerCantPerformAction.selector));
    guardian.cancelRescue();
  }

  function test_confirmRescue() public {
    address feeRecipient = address(10);
    uint256 feeBps = 1000;
    uint256 assetBalance = 12_345_678;
    uint256 rewardBalance = 987_655;
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    vm.mockCall(
      address(asset), abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)), abi.encode(assetBalance)
    );
    vm.mockCall(
      address(reward), abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)), abi.encode(rewardBalance)
    );
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canConfirmRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.confirmRescue.selector, strategyId),
      abi.encode(feeRecipient, feeBps)
    );

    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.confirmRescue.selector, strategyId));
    vm.expectCall(
      address(asset), abi.encodeWithSelector(IERC20.transfer.selector, feeRecipient, assetBalance * feeBps / 10_000)
    );
    vm.expectCall(
      address(reward), abi.encodeWithSelector(IERC20.transfer.selector, feeRecipient, rewardBalance * feeBps / 10_000)
    );

    guardian.confirmRescue();

    assertTrue(guardian.rescueStatus() == ExternalGuardian.RescueStatus.RESCUED);
  }

  function test_confirmRescue_revertWhen_noNeedForConfirmation() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.OK);

    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    guardian.confirmRescue();
  }

  function test_confirmRescue_revertWhen_callerCantConfirmRescue() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canConfirmRescue.selector, strategyId, address(this)),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.CallerCantPerformAction.selector));
    guardian.confirmRescue();
  }
}

contract ExternalGuardianInstance is ExternalGuardian {
  struct Withdrawal {
    address[] tokens;
    uint256[] amounts;
    address recipient;
  }

  struct Deposit {
    address token;
    uint256 amount;
  }

  IEarnStrategy.WithdrawalType private _withdrawalType = IEarnStrategy.WithdrawalType.IMMEDIATE;
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;
  address[] private _tokens;
  Withdrawal private _withdrawal;
  Deposit private _deposit;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_, address[] memory tokens) {
    _registry = registry;
    _strategyId = strategyId_;
    _tokens = tokens;
  }

  function globalRegistry() public view override returns (IGlobalEarnRegistry) {
    return _registry;
  }

  function strategyId() public view override returns (StrategyId) {
    return _strategyId;
  }

  function init(bytes calldata data) external initializer {
    _guardian_init(data);
  }

  function deposit() external view returns (Deposit memory) {
    return _deposit;
  }

  function withdrawal() external view returns (Withdrawal memory) {
    return _withdrawal;
  }

  function setStatus(RescueStatus status) external {
    rescueStatus = status;
  }

  function setWithdrawalType(IEarnStrategy.WithdrawalType withdrawalType) external {
    _withdrawalType = withdrawalType;
  }

  function _guardian_underlying_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  {
    _deposit = Deposit(depositToken, depositAmount);
    return depositAmount;
  }

  function _guardian_underlying_withdraw(
    uint256,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    override
    returns (IEarnStrategy.WithdrawalType[] memory types)
  {
    _withdrawal = Withdrawal(tokens, toWithdraw, recipient);
    types = new IEarnStrategy.WithdrawalType[](tokens.length);
    for (uint256 i; i < types.length; ++i) {
      types[i] = _withdrawalType;
    }
  }

  function _guardian_underlying_specialWithdraw(
    uint256,
    SpecialWithdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata,
    address
  )
    internal
    pure
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    balanceChanges = toWithdraw;
    actualWithdrawnTokens = new address[](0);
    actualWithdrawnAmounts = new uint256[](0);
    result = "";
  }

  function _guardian_underlying_tokens() internal view override returns (address[] memory tokens) {
    return _tokens;
  }

  function _guardian_underlying_maxWithdraw()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    tokens = _tokens;
    withdrawable = CommonUtils.arrayOf(10_000, 20_000);
  }
}
