// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import {
  MorphoStrategyFactory,
  MorphoStrategy,
  StrategyId,
  IERC4626,
  IEarnVault,
  IGlobalEarnRegistry,
  StrategyIdConstants,
  BaseStrategyFactory,
  IEarnBalmyStrategy,
  MorphoStrategyData
} from "src/strategies/instances/morpho/MorphoStrategyFactory.sol";
import { IFeeManagerCore } from "src/interfaces/IFeeManager.sol";
import { ILiquidityMiningManagerCore } from "src/interfaces/ILiquidityMiningManager.sol";
import {
  IValidationManagersRegistryCore,
  ICreationValidationManagerCore
} from "src/interfaces/IValidationManagersRegistry.sol";
import { IGuardianManagerCore } from "src/interfaces/IGuardianManager.sol";
import { Fees } from "src/types/Fees.sol";

// solhint-disable-next-line max-states-count
contract MorphoStrategyTest is Test {
  MockStrategyRegistry private strategyRegistry;
  address private owner = address(2);
  IEarnVault private vault = IEarnVault(address(3));
  IGlobalEarnRegistry private globalRegistry = IGlobalEarnRegistry(address(4));
  IERC4626 private erc4626Vault = IERC4626(address(5));
  address private asset = address(6);
  IFeeManagerCore private feeManager = IFeeManagerCore(address(7));
  address[] private rewardTokens = [address(8), address(9)];
  IValidationManagersRegistryCore private validationManagerRegistry = IValidationManagersRegistryCore(address(9));
  IGuardianManagerCore private guardianManager = IGuardianManagerCore(address(10));
  ILiquidityMiningManagerCore private liquidityMiningManager = ILiquidityMiningManagerCore(address(11));
  bytes private validationManagersStrategyData = abi.encodePacked("registryData");
  bytes private validationData = abi.encode(validationManagersStrategyData, new bytes[](0));
  bytes private guardianData = abi.encodePacked("guardianData");
  bytes private feesData = abi.encodePacked("feesData");
  bytes private liquidityMiningData = abi.encodePacked("liquidityMiningData");
  StrategyId private strategyId = StrategyId.wrap(1);
  MorphoStrategyFactory private factory;

  function setUp() public virtual {
    MorphoStrategy implementation = new MorphoStrategy();
    factory = new MorphoStrategyFactory(implementation);
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
    MorphoStrategy clone = factory.cloneStrategy(
      MorphoStrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData, rewardTokens
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
    (MorphoStrategy clone, StrategyId strategyId_) = factory.cloneStrategyAndRegister(
      owner,
      MorphoStrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData, rewardTokens
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
    MorphoStrategy clone = factory.cloneStrategyWithId(
      strategyId,
      MorphoStrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData, rewardTokens
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
    MorphoStrategy clone = factory.clone2Strategy(
      MorphoStrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData, rewardTokens
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
    (MorphoStrategy clone, StrategyId strategyId_) = factory.clone2StrategyAndRegister(
      owner,
      MorphoStrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData, rewardTokens
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
    MorphoStrategy clone = factory.clone2StrategyWithId(
      strategyId,
      MorphoStrategyData(
        vault, globalRegistry, erc4626Vault, validationData, guardianData, feesData, liquidityMiningData, rewardTokens
      ),
      salt
    );
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId);
  }

  function _assertStrategyWasDeployedCorrectly(MorphoStrategy clone, StrategyId strategyId_) private {
    assertTrue(strategyId_ == strategyId);
    assertTrue(clone.strategyId() == strategyId);
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function _assertStrategyWasDeployedCorrectly(MorphoStrategy clone) private {
    assertEq(address(clone.ERC4626Vault()), address(erc4626Vault));
    assertEq(address(clone.globalRegistry()), address(globalRegistry));
    assertEq(clone.asset(), asset);
    address[] memory tokens = clone.allTokens();
    assertEq(tokens.length, rewardTokens.length + 1);
    assertEq(tokens[0], asset);
    for (uint256 i = 0; i < rewardTokens.length; ++i) {
      assertEq(tokens[i + 1], rewardTokens[i]);
    }
  }
}

contract MockStrategyRegistry {
  function registerStrategy(address) external returns (StrategyId strategyId) {
    strategyId = StrategyId.wrap(1);
    IEarnStrategy(msg.sender).strategyRegistered(strategyId, IEarnStrategy(address(0)), "");
  }
}
