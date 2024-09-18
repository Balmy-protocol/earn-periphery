// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
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
  address private token = address(4);
  StrategyId private strategyId = StrategyId.wrap(1);
  VmSafe.Wallet private alice = vm.createWallet("alice");

  function setUp() public virtual {
    address[] memory tokens = new address[](2);
    tokens[0] = asset;
    tokens[1] = token;
    guardian = new ExternalGuardianInstance(registry, strategyId, tokens);
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("GUARDIAN_MANAGER")),
      abi.encode(manager)
    );
    vm.mockCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector), "");
  }

  function test_init() public {
    bytes memory data = "1234567";
    vm.expectCall(address(manager), abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, data));
    guardian.init(data);
  }
}

contract ExternalGuardianInstance is ExternalGuardian {
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;
  address[] private _tokens;

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
    uint256[] memory,
    address
  )
    internal
    pure
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return new IEarnStrategy.WithdrawalType[](tokens.length);
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

  function _guardian_underlying_tokens() internal view virtual override returns (address[] memory tokens) {
    return _tokens;
  }

  function _guardian_underlying_maxWithdraw()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  { }
}
