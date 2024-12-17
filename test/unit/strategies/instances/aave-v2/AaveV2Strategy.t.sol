// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  AaveV2StrategyFactory,
  AaveV2Strategy,
  StrategyId,
  IEarnVault,
  IGlobalEarnRegistry,
  StrategyIdConstants,
  BaseStrategyFactory,
  IEarnBalmyStrategy,
  IAToken,
  IAaveV2Pool,
  AaveV2StrategyData
} from "src/strategies/instances/aave-v2/AaveV2StrategyFactory.sol";
import { IFeeManagerCore } from "src/interfaces/IFeeManager.sol";
import { ICreationValidationManagerCore } from "src/interfaces/ICreationValidationManager.sol";
import { IGuardianManagerCore } from "src/interfaces/IGuardianManager.sol";
import { Fees } from "src/types/Fees.sol";

// solhint-disable-next-line max-states-count
contract AaveV2StrategyTest is Test {
  IEarnStrategyRegistry private strategyRegistry;
  address private owner = address(2);
  IEarnVault private vault = IEarnVault(address(3));
  IGlobalEarnRegistry private globalRegistry = IGlobalEarnRegistry(address(4));
  IAToken private aToken = IAToken(address(5));
  IAaveV2Pool private aaveV2Pool = IAaveV2Pool(address(6));
  IERC20 private asset = IERC20(address(7));
  IFeeManagerCore private feeManager = IFeeManagerCore(address(8));
  ICreationValidationManagerCore private validationManager = ICreationValidationManagerCore(address(9));
  IGuardianManagerCore private guardianManager = IGuardianManagerCore(address(10));
  bytes private creationValidationData = abi.encodePacked("creationValidationData");
  bytes private guardianData = abi.encodePacked("guardianData");
  bytes private feesData = abi.encodePacked("feesData");
  string private description = "description";
  StrategyId private strategyId = StrategyId.wrap(1);
  AaveV2StrategyFactory private factory;

  function setUp() public virtual {
    AaveV2Strategy implementation = new AaveV2Strategy();
    factory = new AaveV2StrategyFactory(implementation);
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
    vm.mockCall(address(aToken), abi.encodeWithSelector(IAToken.UNDERLYING_ASSET_ADDRESS.selector), abi.encode(asset));
    vm.mockCall(address(asset), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
  }

  function test_cloneStrategy() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), StrategyIdConstants.NO_STRATEGY);
    AaveV2Strategy clone = factory.cloneStrategy(
      AaveV2StrategyData(
        vault, globalRegistry, aToken, aaveV2Pool, creationValidationData, guardianData, feesData, description
      )
    );

    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_cloneStrategyAndRegister() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), strategyId);
    (AaveV2Strategy clone, StrategyId strategyId_) = factory.cloneStrategyAndRegister(
      owner,
      AaveV2StrategyData(
        vault, globalRegistry, aToken, aaveV2Pool, creationValidationData, guardianData, feesData, description
      )
    );

    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_cloneStrategyWithId() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), strategyId);
    AaveV2Strategy clone = factory.cloneStrategyWithId(
      strategyId,
      AaveV2StrategyData(
        vault, globalRegistry, aToken, aaveV2Pool, creationValidationData, guardianData, feesData, description
      )
    );
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function test_clone2Strategy() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, aToken, aaveV2Pool, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), StrategyIdConstants.NO_STRATEGY);
    AaveV2Strategy clone = factory.clone2Strategy(
      AaveV2StrategyData(
        vault, globalRegistry, aToken, aaveV2Pool, creationValidationData, guardianData, feesData, description
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
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, aToken, aaveV2Pool, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    (AaveV2Strategy clone, StrategyId strategyId_) = factory.clone2StrategyAndRegister(
      owner,
      AaveV2StrategyData(
        vault, globalRegistry, aToken, aaveV2Pool, creationValidationData, guardianData, feesData, description
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
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, creationValidationData)
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, aToken, aaveV2Pool, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    AaveV2Strategy clone = factory.clone2StrategyWithId(
      strategyId,
      AaveV2StrategyData(
        vault, globalRegistry, aToken, aaveV2Pool, creationValidationData, guardianData, feesData, description
      ),
      salt
    );

    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function _assertStrategyWasDeployedCorrectly(AaveV2Strategy clone, StrategyId strategyId_) private {
    assertTrue(strategyId_ == strategyId);
    assertTrue(clone.strategyId() == strategyId);
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function _assertStrategyWasDeployedCorrectly(AaveV2Strategy clone) private {
    assertEq(address(clone.aToken()), address(aToken));
    assertEq(address(clone.pool()), address(aaveV2Pool));
    assertEq(address(clone.globalRegistry()), address(globalRegistry));
    assertEq(clone.asset(), address(asset));
    assertEq(clone.description(), description);
  }
}

contract MockStrategyRegistry {
  function registerStrategy(address) external returns (StrategyId strategyId) {
    strategyId = StrategyId.wrap(1);
    IEarnStrategy(msg.sender).strategyRegistered(strategyId, IEarnStrategy(address(0)), "");
  }
}