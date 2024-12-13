// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  CompoundV2StrategyFactory,
  CompoundV2Strategy,
  StrategyId,
  IEarnVault,
  IGlobalEarnRegistry,
  StrategyIdConstants,
  BaseStrategyFactory,
  IEarnBalmyStrategy,
  ICERC20,
  IComptroller,
  CompoundV2StrategyData
} from "src/strategies/instances/compound-v2/CompoundV2StrategyFactory.sol";
import { IFeeManagerCore } from "src/interfaces/IFeeManager.sol";
import { ICreationValidationManagerCore } from "src/interfaces/ICreationValidationManager.sol";
import { IGuardianManagerCore } from "src/interfaces/IGuardianManager.sol";
import { Fees } from "src/types/Fees.sol";

// solhint-disable-next-line max-states-count
contract CompoundV2StrategyTest is Test {
  IEarnStrategyRegistry private strategyRegistry;
  address private owner = address(2);
  IEarnVault private vault = IEarnVault(address(3));
  IGlobalEarnRegistry private globalRegistry = IGlobalEarnRegistry(address(4));
  ICERC20 private cToken = ICERC20(address(5));
  IComptroller private comptroller = IComptroller(address(6));
  IERC20 private comp = IERC20(address(7));
  address private asset = address(8);
  IFeeManagerCore private feeManager = IFeeManagerCore(address(9));
  ICreationValidationManagerCore private validationManager = ICreationValidationManagerCore(address(10));
  IGuardianManagerCore private guardianManager = IGuardianManagerCore(address(11));
  bytes private validationData = abi.encodePacked("validationData");
  bytes private guardianData = abi.encodePacked("guardianData");
  bytes private feesData = abi.encodePacked("feesData");
  string private description = "description";
  StrategyId private strategyId = StrategyId.wrap(1);
  CompoundV2StrategyFactory private factory;

  function setUp() public virtual {
    CompoundV2Strategy implementation = new CompoundV2Strategy();
    factory = new CompoundV2StrategyFactory(implementation);
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
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("GUARDIAN_MANAGER")),
      abi.encode(guardianManager)
    );
    vm.mockCall(
      address(guardianManager), abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector), ""
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("CREATION_VALIDATION_MANAGER")),
      abi.encode(validationManager)
    );
    vm.mockCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector),
      ""
    );
    vm.mockCall(address(cToken), abi.encodeWithSelector(ICERC20.underlying.selector), abi.encode(asset));
    vm.mockCall(address(asset), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
  }

  function test_cloneStrategy() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, validationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), StrategyIdConstants.NO_STRATEGY);
    CompoundV2Strategy clone = factory.cloneStrategy(
      CompoundV2StrategyData(
        vault, globalRegistry, asset, cToken, comptroller, comp, validationData, guardianData, feesData, description
      )
    );

    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_cloneStrategyAndRegister() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, validationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), strategyId);
    (CompoundV2Strategy clone, StrategyId strategyId_) = factory.cloneStrategyAndRegister(
      owner,
      CompoundV2StrategyData(
        vault, globalRegistry, asset, cToken, comptroller, comp, validationData, guardianData, feesData, description
      )
    );

    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_cloneStrategyWithId() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, validationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), strategyId);
    CompoundV2Strategy clone = factory.cloneStrategyWithId(
      strategyId,
      CompoundV2StrategyData(
        vault, globalRegistry, asset, cToken, comptroller, comp, validationData, guardianData, feesData, description
      )
    );
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function test_clone2Strategy() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, validationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, asset, cToken, comptroller, comp, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), StrategyIdConstants.NO_STRATEGY);
    CompoundV2Strategy clone = factory.clone2Strategy(
      CompoundV2StrategyData(
        vault, globalRegistry, asset, cToken, comptroller, comp, validationData, guardianData, feesData, description
      ),
      salt
    );
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_clone2StrategyAndRegister() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, validationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, asset, cToken, comptroller, comp, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    (CompoundV2Strategy clone, StrategyId strategyId_) = factory.clone2StrategyAndRegister(
      owner,
      CompoundV2StrategyData(
        vault, globalRegistry, asset, cToken, comptroller, comp, validationData, guardianData, feesData, description
      ),
      salt
    );

    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_clone2StrategyWithId() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, validationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, asset, cToken, comptroller, comp, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    CompoundV2Strategy clone = factory.clone2StrategyWithId(
      strategyId,
      CompoundV2StrategyData(
        vault, globalRegistry, asset, cToken, comptroller, comp, validationData, guardianData, feesData, description
      ),
      salt
    );

    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function _assertStrategyWasDeployedCorrectly(CompoundV2Strategy clone, StrategyId strategyId_) private {
    assertTrue(strategyId_ == strategyId);
    assertTrue(clone.strategyId() == strategyId);
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function _assertStrategyWasDeployedCorrectly(CompoundV2Strategy clone) private {
    assertEq(address(clone.cToken()), address(cToken));
    assertEq(address(clone.comptroller()), address(comptroller));
    assertEq(address(clone.comp()), address(comp));
    assertEq(address(clone.globalRegistry()), address(globalRegistry));
    assertEq(clone.asset(), asset);
    assertEq(clone.description(), description);
  }

  function _assertCanReceiveNative(CompoundV2Strategy clone) private {
    Address.sendValue(payable(address(clone)), 0.1 ether);
    assertEq(address(clone).balance, 0.1 ether);
  }
}

contract MockStrategyRegistry {
  function registerStrategy(address) external returns (StrategyId strategyId) {
    strategyId = StrategyId.wrap(1);
    IEarnStrategy(msg.sender).strategyRegistered(strategyId, IEarnStrategy(address(0)), "");
  }
}
