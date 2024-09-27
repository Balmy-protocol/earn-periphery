// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { ILiquidityMiningManagerCore } from "src/interfaces/ILiquidityMiningManager.sol";
import { ExternalLiquidityMining } from "src/strategies/layers/liquidity-mining/ExternalLiquidityMining.sol";
import { IEarnStrategy, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
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
  }

  function test_init() public {
    liquidityMining.init();
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
}

contract ExternalLiquidityMiningInstance is ExternalLiquidityMining {
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;
  address[] private _tokens;
  mapping(address token => uint256 balance) private _underlyingBalance;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_, address[] memory tokens) {
    _registry = registry;
    _strategyId = strategyId_;
    _tokens = tokens;
  }

  function init() external initializer {
    _liquidity_mining_init();
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

  function _liquidity_mining_underlying_allTokens() internal view virtual override returns (address[] memory tokens) {
    return _tokens;
  }

  function _liquidity_mining_underlying_maxWithdraw()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  { }

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
}
