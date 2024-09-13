// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import {
  SpecialWithdrawalCode,
  IFeeManager,
  ExternalFees,
  IGlobalEarnRegistry,
  StrategyId,
  Fees,
  IEarnStrategy
} from "src/strategies/fees/ExternalFees.sol";

contract ExternalFeesTest is Test {
  ExternalFeesInstance private fees;
  IGlobalEarnRegistry private registry = IGlobalEarnRegistry(address(1));
  IFeeManager private manager = IFeeManager(address(2));
  StrategyId private strategyId = StrategyId.wrap(1);
  VmSafe.Wallet private alice = vm.createWallet("alice");

  function setUp() public virtual {
    fees = new ExternalFeesInstance(registry, strategyId);
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("FEE_MANAGER")),
      abi.encode(manager)
    );
  }

  function test_fees() public {
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManager.getFees.selector, strategyId),
      abi.encode(Fees({ depositFee: 100, withdrawFee: 0, performanceFee: 300, rescueFee: 0 }))
    );
    (IEarnStrategy.FeeType[] memory types, uint16[] memory bps) = fees.fees();
    assertEq(types.length, 2);
    assertTrue(types[0] == IEarnStrategy.FeeType.DEPOSIT);
    assertTrue(types[1] == IEarnStrategy.FeeType.PERFORMANCE);
    assertEq(bps.length, 2);
    assertEq(bps[0], 100);
    assertEq(bps[1], 300);
  }
}

contract ExternalFeesInstance is ExternalFees {
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_) {
    _registry = registry;
    _strategyId = strategyId_;
  }

  function fees() external view returns (IEarnStrategy.FeeType[] memory types, uint16[] memory bps) {
    return _fees_fees();
  }

  function globalRegistry() public view override returns (IGlobalEarnRegistry) {
    return _registry;
  }

  function strategyId() public view override returns (StrategyId) {
    return _strategyId;
  }

  function _fees_underlying_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  { }

  function _fees_underlying_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  { }

  function _fees_underlying_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  { }

  function _fees_underlying_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
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
  { }
}
