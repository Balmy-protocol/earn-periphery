// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  AaveV3StrategyFactory,
  AaveV3Strategy,
  StrategyId,
  IEarnVault,
  IGlobalEarnRegistry,
  BaseStrategyFactory,
  IEarnBalmyStrategy,
  IAToken,
  IAaveV3Pool,
  IAaveV3Rewards,
  AaveV3StrategyData,
  StrategyIdConstants
} from "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";
import { IFeeManagerCore } from "src/interfaces/IFeeManager.sol";
import { ICreationValidationManagerCore } from "src/interfaces/ICreationValidationManager.sol";
import { IGuardianManagerCore } from "src/interfaces/IGuardianManager.sol";
import { Fees } from "src/types/Fees.sol";

// solhint-disable-next-line max-states-count
contract AaveV3StrategyTest is Test {
  IEarnStrategyRegistry private strategyRegistry;
  address private owner = address(2);
  IEarnVault private vault = IEarnVault(address(3));
  IGlobalEarnRegistry private globalRegistry = IGlobalEarnRegistry(address(4));
  IAToken private aToken = IAToken(address(5));
  IAaveV3Pool private aaveV3Pool = IAaveV3Pool(address(6));
  IAaveV3Rewards private aaveV3Rewards = IAaveV3Rewards(address(7));
  address private asset = address(8);
  IFeeManagerCore private feeManager = IFeeManagerCore(address(9));
  ICreationValidationManagerCore private validationManager = ICreationValidationManagerCore(address(10));
  IGuardianManagerCore private guardianManager = IGuardianManagerCore(address(11));
  bytes private creationValidationData = abi.encodePacked("creationValidationData");
  bytes private guardianData = abi.encodePacked("guardianData");
  bytes private feesData = abi.encodePacked("feesData");
  string private description = "description";
  StrategyId private strategyId = StrategyId.wrap(1);
  AaveV3StrategyFactory private factory;

  function setUp() public virtual {
    AaveV3Strategy implementation = new AaveV3Strategy();
    factory = new AaveV3StrategyFactory(implementation);
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
    AaveV3Strategy clone = factory.cloneStrategy(
      AaveV3StrategyData(
        vault,
        globalRegistry,
        aToken,
        aaveV3Pool,
        aaveV3Rewards,
        creationValidationData,
        guardianData,
        feesData,
        description
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
    (AaveV3Strategy clone, StrategyId strategyId_) = factory.cloneStrategyAndRegister(
      owner,
      AaveV3StrategyData(
        vault,
        globalRegistry,
        aToken,
        aaveV3Pool,
        aaveV3Rewards,
        creationValidationData,
        guardianData,
        feesData,
        description
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
    AaveV3Strategy clone = factory.cloneStrategyWithId(
      strategyId,
      AaveV3StrategyData(
        vault,
        globalRegistry,
        aToken,
        aaveV3Pool,
        aaveV3Rewards,
        creationValidationData,
        guardianData,
        feesData,
        description
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
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, aToken, aaveV3Pool, aaveV3Rewards, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), StrategyIdConstants.NO_STRATEGY);
    AaveV3Strategy clone = factory.clone2Strategy(
      AaveV3StrategyData(
        vault,
        globalRegistry,
        aToken,
        aaveV3Pool,
        aaveV3Rewards,
        creationValidationData,
        guardianData,
        feesData,
        description
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
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, aToken, aaveV3Pool, aaveV3Rewards, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    (AaveV3Strategy clone, StrategyId strategyId_) = factory.clone2StrategyAndRegister(
      owner,
      AaveV3StrategyData(
        vault,
        globalRegistry,
        aToken,
        aaveV3Pool,
        aaveV3Rewards,
        creationValidationData,
        guardianData,
        feesData,
        description
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
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, aToken, aaveV3Pool, aaveV3Rewards, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    AaveV3Strategy clone = factory.clone2StrategyWithId(
      strategyId,
      AaveV3StrategyData(
        vault,
        globalRegistry,
        aToken,
        aaveV3Pool,
        aaveV3Rewards,
        creationValidationData,
        guardianData,
        feesData,
        description
      ),
      salt
    );

    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function _assertStrategyWasDeployedCorrectly(AaveV3Strategy clone, StrategyId strategyId_) private {
    assertTrue(strategyId_ == strategyId);
    assertTrue(clone.strategyId() == strategyId);
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function _assertStrategyWasDeployedCorrectly(AaveV3Strategy clone) private {
    assertEq(address(clone.aToken()), address(aToken));
    assertEq(address(clone.pool()), address(aaveV3Pool));
    assertEq(address(clone.rewards()), address(aaveV3Rewards));
    assertEq(address(clone.globalRegistry()), address(globalRegistry));
    assertEq(clone.asset(), asset);
    assertEq(clone.description(), description);
  }
}

contract MockStrategyRegistry {
  function registerStrategy(address) external returns (StrategyId strategyId) {
    strategyId = StrategyId.wrap(1);
    IEarnStrategy(msg.sender).strategyRegistered(strategyId, IEarnStrategy(address(0)), "");
  }
}
