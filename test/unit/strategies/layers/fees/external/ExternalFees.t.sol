// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import {
  SpecialWithdrawalCode,
  IFeeManagerCore,
  ExternalFees,
  IGlobalEarnRegistry,
  StrategyId,
  Fees,
  IEarnStrategy
} from "src/strategies/layers/fees/external/ExternalFees.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";

contract ExternalFeesTest is Test {
  ExternalFeesInstance private fees;
  IGlobalEarnRegistry private registry = IGlobalEarnRegistry(address(1));
  IFeeManagerCore private manager = IFeeManagerCore(address(2));
  address private asset = address(3);
  address private token = address(4);
  StrategyId private strategyId = StrategyId.wrap(1);

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
    vm.mockCall(address(manager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector), abi.encode());
  }

  function test_init() public {
    _setFee(500); // 5%
    bytes memory data = "1234567";
    vm.expectCall(address(manager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, data));
    fees.init(data);
  }

  function test_fees() public {
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.getFees.selector, strategyId),
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

  function test_withdrawFees_revertWhen_callerCantWithdrawFees() public {
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(ExternalFees.CantWithdrawFees.selector));
    fees.withdrawFees(CommonUtils.arrayOf(asset, token), CommonUtils.arrayOf(100, 100), address(0));
  }

  function test_withdrawFees_revertWhen_invalidTokensLength() public {
    _setFee(500); // 5%
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(true)
    );

    // Deposit 100k
    fees.deposit(asset, 100_000);
    // Set balance to 150k (so yield was 50k, and fees would be 2.5k)
    fees.setBalance(asset, 150_000);
    vm.expectRevert(abi.encodeWithSelector(ExternalFees.InvalidTokens.selector));
    fees.withdrawFees(CommonUtils.arrayOf(asset), CommonUtils.arrayOf(100), address(0));
  }

  function test_withdrawFees_revertWhen_invalidTokens() public {
    _setFee(500); // 5%
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(true)
    );
    // Deposit 100k
    fees.deposit(asset, 100_000);
    // Set balance to 150k (so yield was 50k, and fees would be 2.5k)
    fees.setBalance(asset, 150_000);
    vm.expectRevert(abi.encodeWithSelector(ExternalFees.InvalidTokens.selector));
    fees.withdrawFees(CommonUtils.arrayOf(asset, address(10)), CommonUtils.arrayOf(100, 0), address(0));
  }

  function test_withdrawFees_revertWhen_notEnoughFees() public {
    _setFee(500); // 5%
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(true)
    );

    // Deposit 100k
    fees.deposit(asset, 100_000);

    // Set balance to 150k (so yield was 50k, and fees would be 2.5k)
    fees.setBalance(asset, 150_000);

    vm.expectRevert(abi.encodeWithSelector(ExternalFees.NotEnoughFees.selector));
    fees.withdrawFees(CommonUtils.arrayOf(asset, token), CommonUtils.arrayOf(3000, 0), address(0));
  }

  function test_withdrawFees_revertWhen_withdrawingDelayed() public {
    _setFee(500); // 5%
    fees.setType(asset, IEarnStrategy.WithdrawalType.DELAYED);
    address recipient = address(100);
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(true)
    );

    // Deposit 100k
    fees.deposit(asset, 100_000);
    // Set balance to 150k (so yield was 50k, and fees would be 2.5k)
    fees.setBalance(asset, 150_000);

    vm.expectRevert(abi.encodeWithSelector(ExternalFees.WithdrawMustBeImmediate.selector));
    fees.withdrawFees(CommonUtils.arrayOf(asset, token), CommonUtils.arrayOf(2500, 0), recipient);
  }

  function test_withdrawFees() public {
    _setFee(500); // 5%
    fees.setType(token, IEarnStrategy.WithdrawalType.DELAYED); // We set it for delayed, but we won't withdraw anything
    address recipient = address(100);
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(true)
    );

    // Deposit 100k
    fees.deposit(asset, 100_000);

    // Set balance to 150k (so yield was 50k, and fees would be 2.5k)
    fees.setBalance(asset, 150_000);

    fees.withdrawFees(CommonUtils.arrayOf(asset, token), CommonUtils.arrayOf(2500, 0), recipient);

    // Make sure fees were updated
    (address[] memory tokens, uint256[] memory collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 0);
    assertEq(collected[1], 0);

    // Make sure underlying withdraw was executed correctly
    ExternalFeesInstance.Withdrawal memory withdrawal = fees.lastWithdrawal();
    assertEq(withdrawal.positionId, 0);
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, token));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(2500, 0));
    assertEq(withdrawal.recipient, recipient);
  }

  // Revert if caller cant withdraw
  // Revert if not enough fees
  // Ok
  //  - Fees are updated
  //  - special withdraw is called correctly

  function test_specialWithdrawFees_revertWhen_callerCantWithdrawFees() public {
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(false)
    );
    vm.expectRevert(abi.encodeWithSelector(ExternalFees.CantWithdrawFees.selector));
    fees.specialWithdrawFees(SpecialWithdrawalCode.wrap(1), CommonUtils.arrayOf(100, 100), "", address(0));
  }

  function test_specialWithdrawFees_revertWhen_notEnoughFees() public {
    _setFee(500); // 5%
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(true)
    );

    // Deposit 100k
    fees.deposit(asset, 100_000);

    // Set balance to 150k (so yield was 50k, and fees would be 2.5k)
    fees.setBalance(asset, 150_000);

    vm.expectRevert(abi.encodeWithSelector(ExternalFees.NotEnoughFees.selector));
    fees.specialWithdrawFees(SpecialWithdrawalCode.wrap(1), CommonUtils.arrayOf(3000, 0), "", address(0));
  }

  function test_specialWithdrawFees() public {
    _setFee(500); // 5%
    SpecialWithdrawalCode code = SpecialWithdrawalCode.wrap(1);
    uint256[] memory toWithdraw = CommonUtils.arrayOf(2500, 0);
    bytes memory withdrawData = "12345";
    address recipient = address(15);
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.canWithdrawFees.selector, strategyId, address(this)),
      abi.encode(true)
    );

    // Deposit 100k
    fees.deposit(asset, 100_000);

    // Set balance to 150k (so yield was 50k, and fees would be 2.5k)
    fees.setBalance(asset, 150_000);

    fees.specialWithdrawFees(code, toWithdraw, withdrawData, recipient);

    // Make sure fees were updated
    (address[] memory tokens, uint256[] memory collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 0);
    assertEq(collected[1], 0);

    // Make sure underlying special withdraw was executed correctly
    ExternalFeesInstance.SpecialWithdrawal memory specialWithdrawal = fees.lastSpecialWithdrawal();
    assertEq(specialWithdrawal.positionId, 0);
    assertTrue(specialWithdrawal.withdrawalCode == code);
    assertEq(specialWithdrawal.toWithdraw, toWithdraw);
    assertEq(specialWithdrawal.withdrawData, withdrawData);
    assertEq(specialWithdrawal.recipient, recipient);
  }

  function test_totalBalances() public {
    _setFee(500); // 5%
    fees.strategyRegistered(StrategyId.wrap(1), IEarnStrategy(address(0)), ""); // Register so that performance data is
      // set

    // Deposit 50k
    fees.deposit(asset, 50_000);

    // Set balance to 100k for asset and 50k for reward
    fees.setBalance(asset, 100_000);
    fees.setBalance(token, 50_000);

    (address[] memory tokens, uint256[] memory balances) = fees.totalBalances();

    assertEq(tokens.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(balances.length, 2);
    assertEq(balances[0], 100_000 - 2500); // 5% fee
    assertEq(balances[1], 50_000 - 2500); // 5% fee
  }

  function test_totalBalances_loss() public {
    _setFee(500); // 5%
    uint256 positionId = 1;
    address recipient = address(0);
    address[] memory allTokens = CommonUtils.arrayOf(asset, token);
    fees.strategyRegistered(StrategyId.wrap(1), IEarnStrategy(address(0)), ""); // Register so that performance data is
      // set

    // Deposit 50k
    fees.deposit(asset, 50_000);

    // Set balance to 100k for asset (yield was 50k, fee is 2.5k)
    fees.setBalance(asset, 100_000);

    // Withdraw 50k
    fees.withdraw(positionId, allTokens, CommonUtils.arrayOf(50_000, 0), recipient);

    // Set balance to 1k (there was a big loss)
    fees.setBalance(asset, 1000);

    (address[] memory tokens, uint256[] memory balances) = fees.totalBalances();
    (, uint256[] memory collected) = fees.collectedFees();

    assertEq(tokens.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(balances.length, 2);
    assertEq(balances[0], 0); // Balance is 0 as the 1k will be considered fee
    assertEq(balances[1], 0);
    assertEq(collected.length, 2);
    assertEq(collected[0], 1000);
    assertEq(collected[1], 0);
  }

  function test_deposit() public {
    _setFee(500); // 5%

    // Deposit 100k
    fees.deposit(asset, 100_000);

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
    fees.deposit(asset, 100_000);

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

  function test_deposit_loss() public {
    _setFee(500); // 5%

    // Deposit 100k
    fees.deposit(asset, 100_000);

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
    fees.deposit(asset, 100_000);

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

  function test_withdraw() public {
    uint256 positionId = 1;
    address recipient = address(0);
    address[] memory allTokens = CommonUtils.arrayOf(asset, token);
    _setFee(500); // 5%

    // Set balance to 100k for asset and 50k for reward
    fees.setBalance(asset, 100_000);
    fees.setBalance(token, 50_000);

    // Withdraw 50k and 10k
    fees.withdraw(positionId, allTokens, CommonUtils.arrayOf(50_000, 10_000), recipient);

    // Set balance to 80k for asset and 80k for reward (30k and 40k yield)
    fees.setBalance(asset, 80_000);
    fees.setBalance(token, 80_000);

    (address[] memory tokens, uint256[] memory collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 1500);
    assertEq(collected[1], 2000);

    // Withdraw another 10k and 20k
    fees.withdraw(positionId, tokens, CommonUtils.arrayOf(10_000, 20_000), recipient);

    // Set balance to 100k for asset and 50k for reward
    // There was a loss, total yield was 60k and 40k
    fees.setBalance(asset, 100_000);
    fees.setBalance(token, 50_000);

    (tokens, collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 3000);
    assertEq(collected[1], 2000);
  }

  function test_withdraw_noFees() public {
    uint256 positionId = 1;
    address recipient = address(0);
    address[] memory allTokens = CommonUtils.arrayOf(asset, token);
    _setFee(0); // 0%

    // Set balance to 100k for asset and 50k for reward
    fees.setBalance(asset, 100_000);
    fees.setBalance(token, 50_000);

    (address[] memory tokens1, uint256[] memory balances1) = fees.totalBalances();
    assertEq(tokens1, allTokens);
    assertEq(balances1, CommonUtils.arrayOf(100_000, 50_000));

    // Withdraw 50k and 10k
    fees.withdraw(positionId, allTokens, CommonUtils.arrayOf(50_000, 10_000), recipient);
    (address[] memory tokens2, uint256[] memory balances2) = fees.totalBalances();
    assertEq(tokens2, allTokens);
    assertEq(balances2, CommonUtils.arrayOf(50_000, 40_000));

    // Set balance to 80k for asset and 80k for reward
    fees.setBalance(asset, 80_000);
    fees.setBalance(token, 80_000);
    (address[] memory tokens3, uint256[] memory balances3) = fees.totalBalances();
    assertEq(tokens3, allTokens);
    assertEq(balances3, CommonUtils.arrayOf(80_000, 80_000));

    (address[] memory tokens4, uint256[] memory collected1) = fees.collectedFees();
    assertEq(tokens4, allTokens);
    assertEq(collected1, CommonUtils.arrayOf(0, 0));

    // Withdraw another 10k and 20k
    fees.withdraw(positionId, allTokens, CommonUtils.arrayOf(10_000, 20_000), recipient);
    (address[] memory tokens5, uint256[] memory balances4) = fees.totalBalances();
    assertEq(tokens5, allTokens);
    assertEq(balances4, CommonUtils.arrayOf(70_000, 60_000));

    // Set balance to 100k for asset and 50k for reward
    fees.setBalance(asset, 100_000);
    fees.setBalance(token, 50_000);

    (address[] memory tokens6, uint256[] memory collected2) = fees.collectedFees();
    assertEq(tokens6, allTokens);
    assertEq(collected2, CommonUtils.arrayOf(0, 0));
  }

  function test_specialWithdraw() public {
    uint256 positionId = 1;
    address recipient = address(0);
    _setFee(500); // 5%

    // Set balance to 100k for asset and 50k for reward
    fees.setBalance(asset, 100_000);
    fees.setBalance(token, 50_000);

    // Withdraw 50k and 10k
    fees.specialWithdraw(positionId, SpecialWithdrawalCode.wrap(0), CommonUtils.arrayOf(50_000, 10_000), "", recipient);

    // Set balance to 80k for asset and 80k for reward (30k and 40k yield)
    fees.setBalance(asset, 80_000);
    fees.setBalance(token, 80_000);

    (address[] memory tokens, uint256[] memory collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 1500);
    assertEq(collected[1], 2000);

    // Withdraw another 10k and 20k
    fees.specialWithdraw(positionId, SpecialWithdrawalCode.wrap(0), CommonUtils.arrayOf(10_000, 20_000), "", recipient);

    // Set balance to 100k for asset and 50k for reward
    // There was a loss, total yield was 60k and 40k
    fees.setBalance(asset, 100_000);
    fees.setBalance(token, 50_000);

    (tokens, collected) = fees.collectedFees();
    assertEq(tokens.length, 2);
    assertEq(collected.length, 2);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], token);
    assertEq(collected[0], 3000);
    assertEq(collected[1], 2000);
  }

  function _setFee(uint16 bps) private {
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(IFeeManagerCore.getFees.selector, strategyId),
      abi.encode(Fees({ depositFee: 0, withdrawFee: 0, performanceFee: bps, rescueFee: 0 }))
    );
  }
}

contract ExternalFeesInstance is ExternalFees {
  struct Withdrawal {
    uint256 positionId;
    address[] tokens;
    uint256[] amounts;
    address recipient;
  }

  struct SpecialWithdrawal {
    uint256 positionId;
    SpecialWithdrawalCode withdrawalCode;
    uint256[] toWithdraw;
    bytes withdrawData;
    address recipient;
  }

  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;
  address[] private _tokens;
  mapping(address token => uint256 balance) private _balances;
  mapping(address token => IEarnStrategy.WithdrawalType withdrawalType) private _types;
  Withdrawal private _withdrawal;
  SpecialWithdrawal private _specialWithdrawal;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_, address[] memory tokens) {
    _registry = registry;
    _strategyId = strategyId_;
    _tokens = tokens;
  }

  function fees() external view returns (IEarnStrategy.FeeType[] memory types, uint16[] memory bps) {
    return _fees_fees();
  }

  function totalBalances() external view returns (address[] memory tokens, uint256[] memory balances) {
    return _fees_totalBalances();
  }

  function deposit(address token, uint256 amount) external returns (uint256) {
    return _fees_deposit(token, amount);
  }

  function lastWithdrawal() external view returns (Withdrawal memory) {
    return _withdrawal;
  }

  function lastSpecialWithdrawal() external view returns (SpecialWithdrawal memory) {
    return _specialWithdrawal;
  }

  function withdraw(
    uint256 positionId,
    address[] calldata tokens,
    uint256[] calldata toWithdraw,
    address recipient
  )
    external
  {
    _fees_withdraw(positionId, tokens, toWithdraw, recipient);
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
    return _fees_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
  }

  function strategyRegistered(
    StrategyId strategyId_,
    IEarnStrategy oldStrategy,
    bytes calldata migrationResultData
  )
    external
  {
    return _fees_strategyRegistered(strategyId_, oldStrategy, migrationResultData);
  }

  function globalRegistry() public view override returns (IGlobalEarnRegistry) {
    return _registry;
  }

  function strategyId() public view override returns (StrategyId) {
    return _strategyId;
  }

  function init(bytes calldata data) external initializer {
    _fees_init(data);
  }

  function setBalance(address token, uint256 balance) external {
    _balances[token] = balance;
  }

  function setType(address token, IEarnStrategy.WithdrawalType withdrawalType) external {
    _types[token] = withdrawalType;
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

  function _fees_underlying_deposit(
    address,
    uint256 depositAmount
  )
    internal
    pure
    override
    returns (uint256 assetsDeposit)
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
  {
    _withdrawal = Withdrawal(positionId, tokens, toWithdraw, recipient);
    for (uint256 i = 0; i < tokens.length; i++) {
      _balances[tokens[i]] -= toWithdraw[i];
    }
  }

  function _fees_underlying_specialWithdraw(
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
    address[] memory tokens = _tokens;
    for (uint256 i = 0; i < toWithdraw.length; i++) {
      _balances[tokens[i]] -= toWithdraw[i];
    }
    balanceChanges = toWithdraw;
    actualWithdrawnTokens = new address[](0);
    actualWithdrawnAmounts = new uint256[](0);
    result = "";
  }

  function _fees_underlying_asset() internal view override returns (address asset) {
    return _tokens[0];
  }

  function _fees_underlying_tokens() internal view virtual override returns (address[] memory tokens) {
    return _tokens;
  }

  function _fees_underlying_supportedWithdrawals()
    internal
    view
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory types)
  {
    types = new IEarnStrategy.WithdrawalType[](_tokens.length);
    for (uint256 i = 0; i < _tokens.length; i++) {
      types[i] = _types[_tokens[i]];
    }
  }

  function _fees_underlying_strategyRegistered(
    StrategyId strategyId_,
    IEarnStrategy oldStrategy,
    bytes calldata migrationResultData
  )
    internal
    override
  // solhint-disable-next-line no-empty-blocks
  { }
}
