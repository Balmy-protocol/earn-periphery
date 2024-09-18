// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

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
}

contract ExternalGuardianInstance is ExternalGuardian {
  struct Withdrawal {
    address[] tokens;
    uint256[] amounts;
    address recipient;
  }

  IEarnStrategy.WithdrawalType private _withdrawalType = IEarnStrategy.WithdrawalType.IMMEDIATE;
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;
  address[] private _tokens;
  Withdrawal private _withdrawal;

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
    address,
    uint256 depositAmount
  )
    internal
    pure
    override
    returns (uint256 assetsDeposited)
  {
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
