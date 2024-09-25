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
    vm.mockCall(address(asset), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    vm.mockCall(address(reward), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
  }

  function test_init() public {
    bytes memory data = "1234567";
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, data));
    guardian.init(data);
    (uint16 feeBps, address feeRecipient, ExternalGuardian.RescueStatus status) = guardian.rescueConfig();
    assertEq(feeBps, 0);
    assertEq(feeRecipient, address(0));
    assertTrue(status == ExternalGuardian.RescueStatus.OK);
  }

  function test_rescue_ok() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.OK);
    address feeRecipient = address(10);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canStartRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.rescueStarted.selector, strategyId));
    (address[] memory tokens, uint256[] memory withdrawn) = guardian.rescue(feeRecipient);

    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawn, CommonUtils.arrayOf(10_000, 20_000));

    ExternalGuardianInstance.Withdrawal memory withdrawal = guardian.lastWithdrawal();
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(10_000, 20_000));
    assertEq(withdrawal.recipient, address(guardian));
    (uint16 feeBps, address configuredFeeRecipient, ExternalGuardian.RescueStatus status) = guardian.rescueConfig();
    assertEq(feeBps, 12_345);
    assertEq(configuredFeeRecipient, feeRecipient);
    assertTrue(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
  }

  function test_rescue_okWithBalances() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.OK_WITH_BALANCE_ON_STRATEGY);
    address feeRecipient = address(10);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canStartRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.rescueStarted.selector, strategyId));
    (address[] memory tokens, uint256[] memory withdrawn) = guardian.rescue(feeRecipient);

    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawn, CommonUtils.arrayOf(10_000, 20_000));

    ExternalGuardianInstance.Withdrawal memory withdrawal = guardian.lastWithdrawal();
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(10_000, 20_000));
    assertEq(withdrawal.recipient, address(guardian));
    (uint16 feeBps, address configuredFeeRecipient, ExternalGuardian.RescueStatus status) = guardian.rescueConfig();
    assertEq(feeBps, 12_345);
    assertEq(configuredFeeRecipient, feeRecipient);
    assertTrue(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
  }

  function test_rescue_rescueNeedsConfirmation() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    address feeRecipient = address(10);

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IGuardianManagerCore.canStartRescue.selector, strategyId, address(this)),
      abi.encode(true)
    );
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.rescueStarted.selector), 0);
    (address[] memory tokens, uint256[] memory withdrawn) = guardian.rescue(feeRecipient);

    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawn, CommonUtils.arrayOf(10_000, 20_000));

    ExternalGuardianInstance.Withdrawal memory withdrawal = guardian.lastWithdrawal();
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(10_000, 20_000));
    assertEq(withdrawal.recipient, address(guardian));
    (uint16 feeBps, address configuredFeeRecipient, ExternalGuardian.RescueStatus status) = guardian.rescueConfig();
    assertEq(feeBps, 0);
    assertEq(configuredFeeRecipient, address(0));
    assertTrue(status == ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
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
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.rescueCancelled.selector, strategyId));
    guardian.cancelRescue();

    ExternalGuardianInstance.Deposit memory deposit = guardian.lastDeposit();
    assertEq(deposit.token, asset);
    assertEq(deposit.amount, balance);
    (uint16 feeBps, address feeRecipient, ExternalGuardian.RescueStatus status) = guardian.rescueConfig();
    assertEq(feeBps, 0);
    assertEq(feeRecipient, address(0));
    assertTrue(status == ExternalGuardian.RescueStatus.OK);
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
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.rescueCancelled.selector, strategyId));
    guardian.cancelRescue();

    ExternalGuardianInstance.Deposit memory deposit = guardian.lastDeposit();
    assertEq(deposit.token, asset);
    assertEq(deposit.amount, assetBalance);
    (uint16 feeBps, address feeRecipient, ExternalGuardian.RescueStatus status) = guardian.rescueConfig();
    assertEq(feeBps, 0);
    assertEq(feeRecipient, address(0));
    assertTrue(status == ExternalGuardian.RescueStatus.OK_WITH_BALANCE_ON_STRATEGY);
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
    uint256 feeBps = 12_345;
    uint256 assetBalance = 12_345_678;
    uint256 rewardBalance = 987_655;
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    guardian.setFeeRecipient(feeRecipient);
    guardian.setFee(feeBps);

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

    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.rescueConfirmed.selector, strategyId));
    vm.expectCall(
      address(asset), abi.encodeWithSelector(IERC20.transfer.selector, feeRecipient, assetBalance * feeBps / 10_000)
    );
    vm.expectCall(
      address(reward), abi.encodeWithSelector(IERC20.transfer.selector, feeRecipient, rewardBalance * feeBps / 10_000)
    );

    guardian.confirmRescue();

    (uint16 configuredFeeBps, address configuredFeeRecipient, ExternalGuardian.RescueStatus status) =
      guardian.rescueConfig();
    assertEq(configuredFeeBps, feeBps);
    assertEq(configuredFeeRecipient, feeRecipient);
    assertTrue(status == ExternalGuardian.RescueStatus.RESCUED);
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

  function test_totalBalances_ok() public {
    uint256 assetUndelyingBalance = 12_345_678;
    uint256 rewardUnderlyingBalance = 987_655;
    guardian.setStatus(ExternalGuardian.RescueStatus.OK);
    guardian.setUnderlyingBalance(asset, assetUndelyingBalance);
    guardian.setUnderlyingBalance(reward, rewardUnderlyingBalance);

    (address[] memory tokens, uint256[] memory balances) = guardian.totalBalances();
    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(balances, CommonUtils.arrayOf(assetUndelyingBalance, rewardUnderlyingBalance));
  }

  function test_totalBalances_withBalances() public {
    uint256 assetUndelyingBalance = 12_345_678;
    uint256 assetBalanceInContract = 345_789;
    uint256 rewardUnderlyingBalance = 987_655;
    uint256 rewardBalanceInContract = 123_890;
    guardian.setStatus(ExternalGuardian.RescueStatus.OK_WITH_BALANCE_ON_STRATEGY);
    guardian.setUnderlyingBalance(asset, assetUndelyingBalance);
    guardian.setUnderlyingBalance(reward, rewardUnderlyingBalance);
    vm.mockCall(
      address(asset),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)),
      abi.encode(assetBalanceInContract)
    );
    vm.mockCall(
      address(reward),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)),
      abi.encode(rewardBalanceInContract)
    );

    (address[] memory tokens, uint256[] memory balances) = guardian.totalBalances();
    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(
      balances,
      CommonUtils.arrayOf(
        assetUndelyingBalance + assetBalanceInContract, rewardUnderlyingBalance + rewardBalanceInContract
      )
    );
  }

  function test_totalBalances_needsConfirmation() public {
    uint256 assetUndelyingBalance = 12_345_678;
    uint256 assetBalanceInContract = 345_789;
    uint256 rewardUnderlyingBalance = 987_655;
    uint256 rewardBalanceInContract = 123_890;
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    guardian.setUnderlyingBalance(asset, assetUndelyingBalance);
    guardian.setUnderlyingBalance(reward, rewardUnderlyingBalance);
    vm.mockCall(
      address(asset),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)),
      abi.encode(assetBalanceInContract)
    );
    vm.mockCall(
      address(reward),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)),
      abi.encode(rewardBalanceInContract)
    );

    (address[] memory tokens, uint256[] memory balances) = guardian.totalBalances();
    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(
      balances,
      CommonUtils.arrayOf(
        assetUndelyingBalance + assetBalanceInContract, rewardUnderlyingBalance + rewardBalanceInContract
      )
    );
  }

  function test_totalBalances_rescued() public {
    uint256 assetUndelyingBalance = 12_345_678;
    uint256 assetBalanceInContract = 345_789;
    uint256 rewardUnderlyingBalance = 987_655;
    uint256 rewardBalanceInContract = 123_890;
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUED);
    guardian.setUnderlyingBalance(asset, assetUndelyingBalance);
    guardian.setUnderlyingBalance(reward, rewardUnderlyingBalance);
    vm.mockCall(
      address(asset),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)),
      abi.encode(assetBalanceInContract)
    );
    vm.mockCall(
      address(reward),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(guardian)),
      abi.encode(rewardBalanceInContract)
    );

    (address[] memory tokens, uint256[] memory balances) = guardian.totalBalances();
    assertEq(tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(balances, CommonUtils.arrayOf(assetBalanceInContract, rewardBalanceInContract));
  }

  function test_deposit_ok() public {
    uint256 amount = 12_345;
    guardian.setStatus(ExternalGuardian.RescueStatus.OK);
    uint256 deposited = guardian.deposit(asset, amount);
    ExternalGuardianInstance.Deposit memory deposit = guardian.lastDeposit();
    assertEq(deposit.token, asset);
    assertEq(deposit.amount, amount);
    assertEq(deposited, amount);
  }

  function test_deposit_withBalances() public {
    uint256 amount = 12_345;
    guardian.setStatus(ExternalGuardian.RescueStatus.OK_WITH_BALANCE_ON_STRATEGY);
    uint256 deposited = guardian.deposit(asset, amount);
    ExternalGuardianInstance.Deposit memory deposit = guardian.lastDeposit();
    assertEq(deposit.token, asset);
    assertEq(deposit.amount, amount);
    assertEq(deposited, amount);
  }

  function test_deposit_needsConfirmation() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    guardian.deposit(address(0), 0);
  }

  function test_deposit_rescued() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUED);
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    guardian.deposit(address(0), 0);
  }

  function test_specialWithdraw_ok() public {
    uint256 positionId = 2;
    SpecialWithdrawalCode withdrawalCode = SpecialWithdrawalCode.wrap(10);
    uint256[] memory toWithdraw = CommonUtils.arrayOf(1000, 1000);
    bytes memory withdrawData = "12345";
    address recipient = address(15);
    guardian.setStatus(ExternalGuardian.RescueStatus.OK);
    (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    ) = guardian.specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);

    assertEq(balanceChanges, toWithdraw);
    assertEq(actualWithdrawnTokens.length, 0);
    assertEq(actualWithdrawnAmounts.length, 0);
    assertEq(result.length, 0);

    ExternalGuardianInstance.SpecialWithdrawal memory specialWithdrawal = guardian.lastSpecialWithdrawal();
    assertEq(specialWithdrawal.positionId, positionId);
    assertTrue(specialWithdrawal.withdrawalCode == withdrawalCode);
    assertEq(specialWithdrawal.toWithdraw, toWithdraw);
    assertEq(specialWithdrawal.withdrawData, withdrawData);
    assertEq(specialWithdrawal.recipient, recipient);
  }

  function test_specialWithdraw_withBalances() public {
    uint256 positionId = 2;
    SpecialWithdrawalCode withdrawalCode = SpecialWithdrawalCode.wrap(10);
    uint256[] memory toWithdraw = CommonUtils.arrayOf(1000, 1000);
    bytes memory withdrawData = "12345";
    address recipient = address(15);
    guardian.setStatus(ExternalGuardian.RescueStatus.OK_WITH_BALANCE_ON_STRATEGY);
    (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    ) = guardian.specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);

    assertEq(balanceChanges, toWithdraw);
    assertEq(actualWithdrawnTokens.length, 0);
    assertEq(actualWithdrawnAmounts.length, 0);
    assertEq(result.length, 0);

    ExternalGuardianInstance.SpecialWithdrawal memory specialWithdrawal = guardian.lastSpecialWithdrawal();
    assertEq(specialWithdrawal.positionId, positionId);
    assertTrue(specialWithdrawal.withdrawalCode == withdrawalCode);
    assertEq(specialWithdrawal.toWithdraw, toWithdraw);
    assertEq(specialWithdrawal.withdrawData, withdrawData);
    assertEq(specialWithdrawal.recipient, recipient);
  }

  function test_specialWithdraw_needsConfirmation() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUE_NEEDS_CONFIRMATION);
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    guardian.specialWithdraw(2, SpecialWithdrawalCode.wrap(10), CommonUtils.arrayOf(1000, 1000), "12345", address(15));
  }

  function test_specialWithdraw_rescued() public {
    guardian.setStatus(ExternalGuardian.RescueStatus.RESCUED);
    vm.expectRevert(abi.encodeWithSelector(ExternalGuardian.InvalidRescueStatus.selector));
    guardian.specialWithdraw(2, SpecialWithdrawalCode.wrap(10), CommonUtils.arrayOf(1000, 1000), "12345", address(15));
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

  struct SpecialWithdrawal {
    uint256 positionId;
    SpecialWithdrawalCode withdrawalCode;
    uint256[] toWithdraw;
    bytes withdrawData;
    address recipient;
  }

  IEarnStrategy.WithdrawalType private _withdrawalType = IEarnStrategy.WithdrawalType.IMMEDIATE;
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;
  address[] private _tokens;
  Withdrawal private _withdrawal;
  SpecialWithdrawal private _specialWithdrawal;
  Deposit private _deposit;
  mapping(address token => uint256 balance) private _underlyingBalance;

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

  function totalBalances() external view returns (address[] memory tokens, uint256[] memory balances) {
    return _guardian_totalBalances();
  }

  function deposit(address token, uint256 amount) external returns (uint256 assetsDeposited) {
    return _guardian_deposited(token, amount);
  }

  function specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    external
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    return _guardian_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
  }

  function lastDeposit() external view returns (Deposit memory) {
    return _deposit;
  }

  function lastWithdrawal() external view returns (Withdrawal memory) {
    return _withdrawal;
  }

  function lastSpecialWithdrawal() external view returns (SpecialWithdrawal memory) {
    return _specialWithdrawal;
  }

  function setStatus(RescueStatus status) external {
    rescueConfig.status = status;
  }

  function setFeeRecipient(address feeRecipient) external {
    rescueConfig.feeRecipient = feeRecipient;
  }

  function setFee(uint256 feeBps) external {
    rescueConfig.feeBps = uint16(feeBps);
  }

  function setWithdrawalType(IEarnStrategy.WithdrawalType withdrawalType) external {
    _withdrawalType = withdrawalType;
  }

  function setUnderlyingBalance(address token, uint256 balance) external {
    _underlyingBalance[token] = balance;
  }

  function _guardian_underlying_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    tokens = _tokens;
    balances = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      balances[i] = _underlyingBalance[tokens[i]];
    }
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
    uint256 positionId,
    SpecialWithdrawalCode code,
    uint256[] calldata toWithdraw,
    bytes calldata data,
    address recipient
  )
    internal
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    _specialWithdrawal = SpecialWithdrawal(positionId, code, toWithdraw, data, recipient);
    balanceChanges = toWithdraw;
    actualWithdrawnTokens = new address[](0);
    actualWithdrawnAmounts = new uint256[](0);
    result = "";
  }

  function _guardian_underlying_tokens() internal view override returns (address[] memory tokens) {
    return _tokens;
  }

  // solhint-disable-next-line no-empty-blocks
  function _guardian_underlying_maxWithdraw()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    tokens = _tokens;
    withdrawable = CommonUtils.arrayOf(10_000, 20_000);
  }

  function _guardian_rescueFee() internal pure override returns (uint16) {
    return 12_345;
  }
}
