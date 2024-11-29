// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { IEarnStrategy, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import {
  LidoSTETHStrategyFactory,
  LidoSTETHStrategy,
  StrategyId,
  IEarnVault,
  IGlobalEarnRegistry,
  StrategyIdConstants,
  BaseStrategyFactory,
  IEarnBalmyStrategy,
  LidoSTETHStrategyData,
  IDelayedWithdrawalAdapter
} from "src/strategies/instances/lido/LidoSTETHStrategyFactory.sol";
import { IFeeManagerCore } from "src/interfaces/IFeeManager.sol";
import { ITOSManagerCore } from "src/interfaces/ITOSManager.sol";
import { Fees } from "src/types/Fees.sol";

contract LidoSTETHStrategyTest is Test {
  IEarnStrategyRegistry private strategyRegistry;
  address private owner = address(2);
  IEarnVault private vault = IEarnVault(address(3));
  IGlobalEarnRegistry private globalRegistry = IGlobalEarnRegistry(address(4));
  IDelayedWithdrawalAdapter private adapter = IDelayedWithdrawalAdapter(address(5));
  IFeeManagerCore private feeManager = IFeeManagerCore(address(6));
  ITOSManagerCore private tosManager = ITOSManagerCore(address(7));
  bytes private creationValidationData = abi.encodePacked("creationValidationData");
  bytes private feesData = abi.encodePacked("feesData");
  string private description = "description";
  StrategyId private strategyId = StrategyId.wrap(1);
  LidoSTETHStrategyFactory private factory;

  function setUp() public virtual {
    LidoSTETHStrategy implementation = new LidoSTETHStrategy();
    factory = new LidoSTETHStrategyFactory(implementation);
    strategyRegistry = IEarnStrategyRegistry(address(new MockStrategyRegistry()));
    vm.mockCall(
      address(vault),
      abi.encodeWithSelector(IEarnVault.STRATEGY_REGISTRY.selector),
      abi.encode(address(strategyRegistry))
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("FEE_MANAGER")),
      abi.encode(feeManager)
    );
    vm.mockCall(
      address(feeManager), abi.encodeWithSelector(IFeeManagerCore.getFees.selector), abi.encode(Fees(0, 0, 0, 0))
    );
    vm.mockCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector), "");
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("TOS_MANAGER")),
      abi.encode(tosManager)
    );
    vm.mockCall(address(tosManager), abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector), "");
  }

  function test_cloneStrategy() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), StrategyIdConstants.NO_STRATEGY);
    LidoSTETHStrategy clone = factory.cloneStrategy(
      LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description)
    );

    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_cloneStrategyAndRegister() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), strategyId);
    (LidoSTETHStrategy clone, StrategyId strategyId_) = factory.cloneStrategyAndRegister(
      owner, LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description)
    );

    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_cloneStrategyWithId() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), strategyId);
    LidoSTETHStrategy clone = factory.cloneStrategyWithId(
      strategyId, LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description)
    );

    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function test_clone2Strategy() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );

    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, adapter);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), StrategyIdConstants.NO_STRATEGY);
    LidoSTETHStrategy clone = factory.clone2Strategy(
      LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description)
    );
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_clone2StrategyAndRegister() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, adapter);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    (LidoSTETHStrategy clone, StrategyId strategyId_) = factory.clone2StrategyAndRegister(
      owner, LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description)
    );

    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_clone2StrategyWithId() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, adapter);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    (LidoSTETHStrategy clone) = factory.clone2StrategyWithId(
      strategyId, LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description)
    );

    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function test_clone3Strategy() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    address cloneAddress = factory.addressOfClone3(salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), StrategyIdConstants.NO_STRATEGY);
    LidoSTETHStrategy clone = factory.clone3Strategy(
      LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description), salt
    );

    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_clone3StrategyAndRegister() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    address cloneAddress = factory.addressOfClone3(salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    (LidoSTETHStrategy clone, StrategyId strategyId_) = factory.clone3StrategyAndRegister(
      owner, LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description), salt
    );
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_clone3StrategyWithId() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(tosManager),
      abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    address cloneAddress = factory.addressOfClone3(salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    LidoSTETHStrategy clone = factory.clone3StrategyWithId(
      strategyId,
      LidoSTETHStrategyData(vault, globalRegistry, adapter, creationValidationData, feesData, description),
      salt
    );
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function _assertStrategyWasDeployedCorrectly(LidoSTETHStrategy clone, StrategyId strategyId_) private {
    assertTrue(strategyId_ == strategyId);
    assertTrue(clone.strategyId() == strategyId);
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function _assertStrategyWasDeployedCorrectly(LidoSTETHStrategy clone) private {
    assertEq(address(clone.globalRegistry()), address(globalRegistry));
    assertEq(address(clone.vault()), address(vault));
    assertEq(address(clone.delayedWithdrawalAdapter(Token.NATIVE_TOKEN)), address(adapter));
    assertEq(clone.description(), description);
  }
}

contract MockStrategyRegistry {
  function registerStrategy(address) external returns (StrategyId strategyId) {
    strategyId = StrategyId.wrap(1);
    IEarnStrategy(msg.sender).strategyRegistered(strategyId, IEarnStrategy(address(0)), "");
  }
}
