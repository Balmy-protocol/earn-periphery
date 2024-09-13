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
  address private asset = address(3);
  address private token = address(4);
  StrategyId private strategyId = StrategyId.wrap(1);
  VmSafe.Wallet private alice = vm.createWallet("alice");

  function setUp() public virtual {
    address[] memory tokens = new address[](2);
    tokens[0] = asset;
    tokens[1] = token;
    fees = new ExternalFeesInstance(registry, strategyId, tokens);
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

  function test_deposited() public {
    _setFee(500); // 5%

    // Deposit 100k
    fees.deposited(asset, 100_000);

    // Set balance to 150k (so yield was 50k)
    fees.setBalance(asset, 150_000);

    (address[] memory tokens, uint256[] memory collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 2500);
    assertEq(collected[1], 0);

    // Deposit another 100k (balance is now 250k)
    fees.deposited(asset, 100_000);

    // Set balance to 300k (so yield was 100k)
    fees.setBalance(asset, 300_000);

    (tokens, collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 5000);
    assertEq(collected[1], 0);
  }

  function test_deposited_loss() public {
    _setFee(500); // 5%

    // Deposit 100k
    fees.deposited(asset, 100_000);

    // Set balance to 150k (so yield was 50k)
    fees.setBalance(asset, 150_000);

    (address[] memory tokens, uint256[] memory collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 2500);
    assertEq(collected[1], 0);

    // Deposit another 100k (balance is now 250k)
    fees.deposited(asset, 100_000);

    // Set balance to 200k, there was a loss
    fees.setBalance(asset, 200_000);

    // Make sure fees remain the same
    (tokens, collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 2500);
    assertEq(collected[1], 0);
  }

  function _setFee(uint16 bps) private {
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManager.getFees.selector, strategyId),
      abi.encode(Fees({ depositFee: 0, withdrawFee: 0, performanceFee: bps, rescueFee: 0 }))
    );
  }
}

contract ExternalFeesInstance is ExternalFees {
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;
  address[] private _tokens;
  mapping(address token => uint256 balance) private _balances;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_, address[] memory tokens) {
    _registry = registry;
    _strategyId = strategyId_;
    _tokens = tokens;
  }

  function fees() external view returns (IEarnStrategy.FeeType[] memory types, uint16[] memory bps) {
    return _fees_fees();
  }

  function deposited(address token, uint256 amount) external returns (uint256) {
    return _fees_deposited(token, amount);
  }

  function globalRegistry() public view override returns (IGlobalEarnRegistry) {
    return _registry;
  }

  function strategyId() public view override returns (StrategyId) {
    return _strategyId;
  }

  function setBalance(address token, uint256 balance) external {
    _balances[token] = balance;
  }

  function _fees_underlying_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    tokens = _tokens;
    balances = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      balances[i] = _balances[tokens[i]];
    }
  }

  function _fees_underlying_deposited(
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

  function _fees_underlying_asset() internal view override returns (address asset) {
    return _tokens[0];
  }
}
