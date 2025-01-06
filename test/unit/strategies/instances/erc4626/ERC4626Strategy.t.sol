// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  ERC4626StrategyFactory,
  ERC4626Strategy,
  StrategyId,
  IERC4626,
  IEarnVault,
  IGlobalEarnRegistry,
  StrategyIdConstants,
  BaseStrategyFactory,
  IEarnBalmyStrategy,
  ERC4626StrategyData
} from "src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";
import { IFeeManagerCore } from "src/interfaces/IFeeManager.sol";
import { ILiquidityMiningManagerCore } from "src/interfaces/ILiquidityMiningManager.sol";
import {
  IValidationManagersRegistryCore,
  ICreationValidationManagerCore
} from "src/interfaces/IValidationManagersRegistry.sol";
import { IGuardianManagerCore } from "src/interfaces/IGuardianManager.sol";
import { Fees } from "src/types/Fees.sol";

// solhint-disable-next-line max-states-count
contract ERC4626StrategyTest is Test {
  MockStrategyRegistry private strategyRegistry;
  address private owner = address(2);
  IEarnVault private vault = IEarnVault(address(3));
  IGlobalEarnRegistry private globalRegistry = IGlobalEarnRegistry(address(4));
  IERC4626 private erc4626Vault = IERC4626(address(5));
  address private asset = address(6);
  IFeeManagerCore private feeManager = IFeeManagerCore(address(7));
  IValidationManagersRegistryCore private validationManagerRegistry = IValidationManagersRegistryCore(address(9));
  IGuardianManagerCore private guardianManager = IGuardianManagerCore(address(10));
  ILiquidityMiningManagerCore private liquidityMiningManager = ILiquidityMiningManagerCore(address(11));
  bytes private validationManagersStrategyData = abi.encodePacked("registryData");
  bytes private validationData = abi.encode(validationManagersStrategyData, new bytes[](0));
  bytes private guardianData = abi.encodePacked("guardianData");
  bytes private feesData = abi.encodePacked("feesData");
  bytes private liquidityMiningData = abi.encodePacked("liquidityMiningData");
  StrategyId private strategyId = StrategyId.wrap(1);
  ERC4626StrategyFactory private factory;

  function setUp() public virtual {
    ERC4626Strategy implementation = new ERC4626Strategy();
    factory = new ERC4626StrategyFactory(implementation);
    strategyRegistry = new MockStrategyRegistry();
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
      address(liquidityMiningManager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector),
      ""
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("LIQUIDITY_MINING_MANAGER")),
      abi.encode(liquidityMiningManager)
    );
    vm.mockCall(
      address(globalRegistry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("VALIDATION_MANAGERS_REGISTRY")),
      abi.encode(validationManagerRegistry)
    );
    vm.mockCall(
      address(validationManagerRegistry),
      abi.encodeWithSelector(IValidationManagersRegistryCore.strategySelfConfigure.selector),
      abi.encode(new ICreationValidationManagerCore[](0))
    );
    vm.mockCall(address(erc4626Vault), abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));
    vm.mockCall(address(asset), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
  }

  function test_cloneStrategy() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManagerRegistry),
      abi.encodeWithSelector(
        IValidationManagersRegistryCore.strategySelfConfigure.selector, validationManagersStrategyData
      )
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectCall(
      address(liquidityMiningManager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector, liquidityMiningData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), StrategyIdConstants.NO_STRATEGY);
    ERC4626Strategy clone = factory.cloneStrategy(
      ERC4626StrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData
      )
    );

    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_cloneStrategyAndRegister() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManagerRegistry),
      abi.encodeWithSelector(
        IValidationManagersRegistryCore.strategySelfConfigure.selector, validationManagersStrategyData
      )
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectCall(
      address(liquidityMiningManager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector, liquidityMiningData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), strategyId);
    (ERC4626Strategy clone, StrategyId strategyId_) = factory.cloneStrategyAndRegister(
      owner,
      ERC4626StrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData
      )
    );

    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_cloneStrategyWithId() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManagerRegistry),
      abi.encodeWithSelector(
        IValidationManagersRegistryCore.strategySelfConfigure.selector, validationManagersStrategyData
      )
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectCall(
      address(liquidityMiningManager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector, liquidityMiningData)
    );
    vm.expectEmit(false, true, false, false);
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(address(0)), strategyId);
    ERC4626Strategy clone = factory.cloneStrategyWithId(
      strategyId,
      ERC4626StrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData
      )
    );

    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function test_clone2Strategy() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(
      address(validationManagerRegistry),
      abi.encodeWithSelector(
        IValidationManagersRegistryCore.strategySelfConfigure.selector, validationManagersStrategyData
      )
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectCall(
      address(liquidityMiningManager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector, liquidityMiningData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, erc4626Vault, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), StrategyIdConstants.NO_STRATEGY);
    ERC4626Strategy clone = factory.clone2Strategy(
      ERC4626StrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData
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
      address(validationManagerRegistry),
      abi.encodeWithSelector(
        IValidationManagersRegistryCore.strategySelfConfigure.selector, validationManagersStrategyData
      )
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectCall(
      address(liquidityMiningManager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector, liquidityMiningData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, erc4626Vault, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    (ERC4626Strategy clone, StrategyId strategyId_) = factory.clone2StrategyAndRegister(
      owner,
      ERC4626StrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData
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
      address(validationManagerRegistry),
      abi.encodeWithSelector(
        IValidationManagersRegistryCore.strategySelfConfigure.selector, validationManagersStrategyData
      )
    );
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    vm.expectCall(
      address(liquidityMiningManager),
      abi.encodeWithSelector(ILiquidityMiningManagerCore.strategySelfConfigure.selector, liquidityMiningData)
    );
    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, erc4626Vault, salt);
    vm.expectEmit();
    emit BaseStrategyFactory.StrategyCloned(IEarnBalmyStrategy(cloneAddress), strategyId);
    ERC4626Strategy clone = factory.clone2StrategyWithId(
      strategyId,
      ERC4626StrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData
      ),
      salt
    );
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function _assertStrategyWasDeployedCorrectly(ERC4626Strategy clone, StrategyId strategyId_) private {
    assertTrue(strategyId_ == strategyId);
    assertTrue(clone.strategyId() == strategyId);
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function _assertStrategyWasDeployedCorrectly(ERC4626Strategy clone) private {
    assertEq(address(clone.ERC4626Vault()), address(erc4626Vault));
    assertEq(address(clone.globalRegistry()), address(globalRegistry));
    assertEq(clone.asset(), asset);
  }
}

contract MockStrategyRegistry {
  function registerStrategy(address) external returns (StrategyId strategyId) {
    strategyId = StrategyId.wrap(1);
    IEarnStrategy(msg.sender).strategyRegistered(strategyId, IEarnStrategy(address(0)), "");
  }
}
