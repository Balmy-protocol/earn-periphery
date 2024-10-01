// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { ILiquidityMiningManagerCore } from "src/interfaces/ILiquidityMiningManager.sol";
import { ExternalLiquidityMining } from "src/strategies/layers/liquidity-mining/ExternalLiquidityMining.sol";
import { IEarnStrategy, StrategyId, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { CommonUtils } from "../../../../utils/CommonUtils.sol";

contract ExternalLiquidityMiningTest is Test {
  ExternalLiquidityMiningInstance private liquidityMining;
  IGlobalEarnRegistry private registry = IGlobalEarnRegistry(address(1));
  ILiquidityMiningManagerCore private manager = ILiquidityMiningManagerCore(address(2));
  address private asset = address(3);
  address private reward = address(4);
  address private lmReward = address(5);
  address private lmRewardRepeated = reward;

  StrategyId private strategyId = StrategyId.wrap(1);

  function setUp() public virtual {
    liquidityMining = new ExternalLiquidityMiningInstance(registry, strategyId, CommonUtils.arrayOf(asset, reward));
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("LIQUIDITY_MINING_MANAGER")),
      abi.encode(manager)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewards.selector, strategyId),
      abi.encode(CommonUtils.arrayOf(lmReward, lmRewardRepeated))
    );

    vm.mockCall(
      address(manager), abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector), ""
    );
  }

  function test_init() public {
    bytes memory data = "1234567";
    vm.expectCall(
      address(manager), abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector, data)
    );
    liquidityMining.init(data);
  }

  function test_allTokens() public {
    address[] memory tokens = liquidityMining.allTokens();
    assertEq(tokens.length, 3);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], reward);
    assertEq(tokens[2], lmReward);
  }

  function test_totalBalances() public {
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewards.selector, strategyId),
      abi.encode(CommonUtils.arrayOf(lmReward, lmRewardRepeated))
    );

    uint256 lmAmount = 1000;
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmReward),
      abi.encode(lmAmount)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmRewardRepeated),
      abi.encode(lmAmount)
    );

    liquidityMining.setUnderlyingBalance(asset, 123);
    liquidityMining.setUnderlyingBalance(reward, 456);

    (address[] memory tokens, uint256[] memory balances) = liquidityMining.totalBalances();
    assertEq(tokens.length, 3);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], reward);
    assertEq(tokens[2], lmReward);
    assertEq(balances[0], 123);
    assertEq(balances[1], 456 + lmAmount); // reward + lmRewardRepeated
    assertEq(balances[2], lmAmount); //lmReward
  }

  function test_supportedWithdrawals() public {
    IEarnStrategy.WithdrawalType[] memory supported = liquidityMining.supportedWithdrawals();
    assertEq(supported.length, 3);

    assertTrue(supported[0] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(supported[1] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(supported[2] == IEarnStrategy.WithdrawalType.IMMEDIATE);
  }

  function test_deposited() public {
    uint256 amount = 1000; // 1:1 asset to deposited
    vm.expectCall(
      address(manager), abi.encodeWithSelector(ILiquidityMiningManagerCore.deposited.selector, strategyId, amount)
    );
    uint256 deposited = liquidityMining.deposited(asset, amount);
    assertEq(deposited, amount);
  }

  function test_maxWithdraw() public {
    uint256 lmAmount = 1000;
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmReward),
      abi.encode(lmAmount)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmRewardRepeated),
      abi.encode(lmAmount)
    );

    liquidityMining.setUnderlyingBalance(asset, 123);
    liquidityMining.setUnderlyingBalance(reward, 456);

    (address[] memory tokens, uint256[] memory withdrawable) = liquidityMining.maxWithdraw();
    assertEq(tokens.length, 3);
    assertEq(tokens[0], asset);
    assertEq(tokens[1], reward);
    assertEq(tokens[2], lmReward);
    assertEq(withdrawable[0], 123);
    assertEq(withdrawable[1], 456 + lmAmount); // reward + lmRewardRepeated
    assertEq(withdrawable[2], lmAmount); //lmReward
  }

  function test_specialWithdraw() public {
    uint256 positionId = 1;
    SpecialWithdrawalCode withdrawalCode = SpecialWithdrawalCode.wrap(1);
    uint256[] memory toWithdraw = CommonUtils.arrayOf(123);
    bytes memory withdrawData = "1234567";
    address recipient = address(1);
    vm.expectCall(
      address(manager), abi.encodeWithSelector(ILiquidityMiningManagerCore.withdrew.selector, strategyId, toWithdraw[0])
    );
    (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    ) = liquidityMining.specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);

    assertEq(balanceChanges, toWithdraw);
    assertEq(actualWithdrawnTokens.length, 0);
    assertEq(actualWithdrawnAmounts.length, 0);
    assertEq(result.length, 0);

    ExternalLiquidityMiningInstance.SpecialWithdrawal memory specialWithdrawal = liquidityMining.lastSpecialWithdrawal();
    assertEq(specialWithdrawal.positionId, positionId);
    assertTrue(specialWithdrawal.withdrawalCode == withdrawalCode);
    assertEq(specialWithdrawal.toWithdraw, toWithdraw);
    assertEq(specialWithdrawal.withdrawData, withdrawData);
    assertEq(specialWithdrawal.recipient, recipient);
  }

  function test_withdraw_ok() public {
    uint256 positionId = 10;
    uint256 amount = 12_345;
    address recipient = address(30);

    vm.expectCall(
      address(manager), abi.encodeWithSelector(ILiquidityMiningManagerCore.withdrew.selector, strategyId, amount)
    );

    IEarnStrategy.WithdrawalType[] memory types = liquidityMining.withdraw(
      positionId, CommonUtils.arrayOf(asset, reward, lmReward), CommonUtils.arrayOf(amount, 0, 0), recipient
    );
    assertEq(types.length, 3);
    assertTrue(types[0] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[1] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[2] == IEarnStrategy.WithdrawalType.IMMEDIATE);

    // Make sure underlying was called correctly
    ExternalLiquidityMiningInstance.Withdrawal memory withdrawal = liquidityMining.lastWithdrawal();
    assertEq(withdrawal.positionId, positionId);
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(amount, 0));
    assertEq(withdrawal.recipient, recipient);
  }

  function test_withdraw_onlyLiquidityMining() public {
    uint256 positionId = 10;
    uint256 amount = 999;
    address recipient = address(30);

    uint256 lmAmount = 1000;
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmReward),
      abi.encode(lmAmount)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmRewardRepeated),
      abi.encode(lmAmount)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.claim.selector, strategyId, lmReward, lmAmount, recipient),
      abi.encode()
    );

    vm.expectCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.claim.selector, strategyId, lmReward, amount, recipient)
    );

    IEarnStrategy.WithdrawalType[] memory types = liquidityMining.withdraw(
      positionId, CommonUtils.arrayOf(asset, reward, lmReward), CommonUtils.arrayOf(0, 0, amount), recipient
    );
    assertEq(types.length, 3);
    assertTrue(types[0] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[1] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[2] == IEarnStrategy.WithdrawalType.IMMEDIATE);

    // Make sure underlying layer was not called
    ExternalLiquidityMiningInstance.Withdrawal memory withdrawal = liquidityMining.lastWithdrawal();
    assertEq(withdrawal.positionId, 0);
    assertEq(withdrawal.tokens.length, 0);
    assertEq(withdrawal.amounts.length, 0);
    assertEq(withdrawal.recipient, address(0));
  }

  function test_withdraw_notEnoughBalanceSoWillCallUnderlying() public {
    uint256 positionId = 10;
    uint256 amount = 1010;
    address recipient = address(30);

    liquidityMining.setUnderlyingBalance(asset, 123);
    liquidityMining.setUnderlyingBalance(reward, 456);

    uint256 lmAmount = 1000;
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmReward),
      abi.encode(lmAmount)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmRewardRepeated),
      abi.encode(lmAmount)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(
        ILiquidityMiningManagerCore.claim.selector, strategyId, lmRewardRepeated, lmAmount, recipient
      ),
      abi.encode()
    );

    vm.expectCall(
      address(manager),
      abi.encodeWithSelector(
        ILiquidityMiningManagerCore.claim.selector, strategyId, lmRewardRepeated, lmAmount, recipient
      )
    );

    IEarnStrategy.WithdrawalType[] memory types = liquidityMining.withdraw(
      positionId, CommonUtils.arrayOf(asset, reward, lmReward), CommonUtils.arrayOf(0, amount, 0), recipient
    );
    assertEq(types.length, 3);
    assertTrue(types[0] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[1] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[2] == IEarnStrategy.WithdrawalType.IMMEDIATE);

    // Make sure underlying was called correctly
    ExternalLiquidityMiningInstance.Withdrawal memory withdrawal = liquidityMining.lastWithdrawal();
    assertEq(withdrawal.positionId, positionId);
    assertEq(withdrawal.tokens, CommonUtils.arrayOf(asset, reward));
    assertEq(withdrawal.amounts, CommonUtils.arrayOf(0, amount - lmAmount));
    assertEq(withdrawal.recipient, recipient);
  }

  function test_withdraw_enoughBalanceSoWontCallUnderlying() public {
    uint256 positionId = 10;
    uint256 amount = 999;
    address recipient = address(30);

    liquidityMining.setUnderlyingBalance(asset, 123);
    liquidityMining.setUnderlyingBalance(reward, 456);

    uint256 lmAmount = 1000;
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmReward),
      abi.encode(lmAmount)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.rewardAmount.selector, strategyId, lmRewardRepeated),
      abi.encode(lmAmount)
    );

    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(
        ILiquidityMiningManagerCore.claim.selector, strategyId, lmRewardRepeated, lmAmount, recipient
      ),
      abi.encode()
    );

    IEarnStrategy.WithdrawalType[] memory types = liquidityMining.withdraw(
      positionId, CommonUtils.arrayOf(asset, reward, lmReward), CommonUtils.arrayOf(0, amount, 0), recipient
    );
    assertEq(types.length, 3);
    assertTrue(types[0] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[1] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[2] == IEarnStrategy.WithdrawalType.IMMEDIATE);

    // Make sure underlying layer was not called
    ExternalLiquidityMiningInstance.Withdrawal memory withdrawal = liquidityMining.lastWithdrawal();
    assertEq(withdrawal.positionId, 0);
    assertEq(withdrawal.tokens.length, 0);
    assertEq(withdrawal.amounts.length, 0);
    assertEq(withdrawal.recipient, address(0));
  }
}

contract ExternalLiquidityMiningInstance is ExternalLiquidityMining {
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
  mapping(address token => uint256 balance) private _underlyingBalance;
  Withdrawal private _withdrawal;
  SpecialWithdrawal private _specialWithdrawal;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_, address[] memory tokens) {
    _registry = registry;
    _strategyId = strategyId_;
    _tokens = tokens;
  }

  function init(bytes calldata data) external initializer {
    _liquidity_mining_init(data);
  }

  function allTokens() external view virtual returns (address[] memory tokens) {
    return _liquidity_mining_allTokens();
  }

  function totalBalances() external view virtual returns (address[] memory tokens, uint256[] memory balances) {
    return _liquidity_mining_totalBalances();
  }

  function supportedWithdrawals() external view returns (IEarnStrategy.WithdrawalType[] memory) {
    return _liquidity_mining_supportedWithdrawals();
  }

  function deposited(address depositToken, uint256 depositAmount) external returns (uint256 assetsDeposited) {
    return _liquidity_mining_deposited(depositToken, depositAmount);
  }

  function maxWithdraw() external view returns (address[] memory tokens, uint256[] memory withdrawable) {
    return _liquidity_mining_maxWithdraw();
  }

  function withdraw(
    uint256 positionId,
    address[] calldata tokens,
    uint256[] calldata toWithdraw,
    address recipient
  )
    external
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return _liquidity_mining_withdraw(positionId, tokens, toWithdraw, recipient);
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
    return _liquidity_mining_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
  }

  function lastWithdrawal() external view returns (Withdrawal memory) {
    return _withdrawal;
  }

  function lastSpecialWithdrawal() external view returns (SpecialWithdrawal memory) {
    return _specialWithdrawal;
  }

  function _liquidity_mining_underlying_allTokens() internal view virtual override returns (address[] memory tokens) {
    return _tokens;
  }

  function _liquidity_mining_underlying_maxWithdraw()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  // solhint-disable-next-line no-empty-blocks
  {
    return _liquidity_mining_underlying_totalBalances();
  }

  function _liquidity_mining_underlying_totalBalances()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    tokens = new address[](_tokens.length);
    balances = new uint256[](_tokens.length);
    for (uint256 i = 0; i < _tokens.length; i++) {
      tokens[i] = _tokens[i];
      balances[i] = _underlyingBalance[_tokens[i]];
    }
  }

  function setUnderlyingBalance(address token, uint256 balance) external {
    _underlyingBalance[token] = balance;
  }

  function _liquidity_mining_underlying_supportedWithdrawals()
    internal
    view
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return new IEarnStrategy.WithdrawalType[](_tokens.length);
  }

  function globalRegistry() public view virtual override returns (IGlobalEarnRegistry) {
    return _registry;
  }

  function strategyId() public view virtual override returns (StrategyId) {
    return _strategyId;
  }

  function _liquidity_mining_underlying_deposited(
    address,
    uint256 depositAmount
  )
    internal
    virtual
    override
    returns (uint256 assetsDeposited)
  {
    return depositAmount;
  }

  function _liquidity_mining_underlying_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    virtual
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    _specialWithdrawal = SpecialWithdrawal(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);

    balanceChanges = toWithdraw;
    actualWithdrawnTokens = new address[](0);
    actualWithdrawnAmounts = new uint256[](0);
    result = "";
  }

  function _liquidity_mining_underlying_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory types)
  {
    _withdrawal = Withdrawal(positionId, tokens, toWithdraw, recipient);
    return _liquidity_mining_supportedWithdrawals();
  }
}
