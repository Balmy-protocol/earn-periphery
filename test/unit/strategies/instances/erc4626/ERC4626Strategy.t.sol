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
  IEarnStrategyRegistry
} from "src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";
import { IFeeManagerCore } from "src/interfaces/IFeeManager.sol";
import { ITOSManagerCore } from "src/interfaces/ITOSManager.sol";
import { IGuardianManagerCore } from "src/interfaces/IGuardianManager.sol";
import { Fees } from "src/types/Fees.sol";

contract ERC4626StrategyTest is Test {
  IEarnStrategyRegistry private strategyRegistry;
  address private owner = address(2);
  IEarnVault private vault = IEarnVault(address(3));
  IGlobalEarnRegistry private globalRegistry = IGlobalEarnRegistry(address(4));
  IERC4626 private erc4626Vault = IERC4626(address(5));
  address private asset = address(6);
  IFeeManagerCore private feeManager = IFeeManagerCore(address(7));
  ITOSManagerCore private tosManager = ITOSManagerCore(address(8));
  IGuardianManagerCore private guardianManager = IGuardianManagerCore(address(9));
  bytes private tosData = abi.encodePacked("tosData");
  bytes private guardianData = abi.encodePacked("guardianData");
  bytes private feesData = abi.encodePacked("feesData");
  string private description = "description";
  StrategyId private strategyId = StrategyId.wrap(1);
  ERC4626StrategyFactory private factory;

  function setUp() public virtual {
    ERC4626Strategy implementation = new ERC4626Strategy();
    factory = new ERC4626StrategyFactory(implementation);
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
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("TOS_MANAGER")),
      abi.encode(tosManager)
    );
    vm.mockCall(address(tosManager), abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector), "");
    vm.mockCall(address(erc4626Vault), abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(asset));
    vm.mockCall(address(asset), abi.encodeWithSelector(IERC20.approve.selector), abi.encode(true));
  }

  function test_cloneStrategy() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(address(tosManager), abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, tosData));
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    ERC4626Strategy clone =
      factory.cloneStrategy(vault, globalRegistry, erc4626Vault, tosData, guardianData, feesData, description);

    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_cloneStrategyAndRegister() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(address(tosManager), abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, tosData));
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    (ERC4626Strategy clone, StrategyId strategyId_) = factory.cloneStrategyAndRegister(
      owner, vault, globalRegistry, erc4626Vault, tosData, guardianData, feesData, description
    );

    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_clone2Strategy() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(address(tosManager), abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, tosData));
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    ERC4626Strategy clone =
      factory.clone2Strategy(vault, globalRegistry, erc4626Vault, tosData, guardianData, feesData, description);

    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, erc4626Vault);
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function clone2StrategyAndRegister() public {
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(address(tosManager), abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, tosData));
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    (ERC4626Strategy clone, StrategyId strategyId_) = factory.clone2StrategyAndRegister(
      owner, vault, globalRegistry, erc4626Vault, tosData, guardianData, feesData, description
    );

    address cloneAddress = factory.addressOfClone2(vault, globalRegistry, erc4626Vault);
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
  }

  function test_clone3Strategy() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(address(tosManager), abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, tosData));
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    (ERC4626Strategy clone) =
      factory.clone3Strategy(vault, globalRegistry, erc4626Vault, salt, tosData, guardianData, feesData, description);

    address cloneAddress = factory.addressOfClone3(salt);
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone);
  }

  function test_clone3StrategyAndRegister() public {
    bytes32 salt = bytes32(uint256(12_345));
    vm.expectCall(address(feeManager), abi.encodeWithSelector(IFeeManagerCore.strategySelfConfigure.selector, feesData));
    vm.expectCall(address(tosManager), abi.encodeWithSelector(ITOSManagerCore.strategySelfConfigure.selector, tosData));
    vm.expectCall(
      address(guardianManager),
      abi.encodeWithSelector(IGuardianManagerCore.strategySelfConfigure.selector, guardianData)
    );
    (ERC4626Strategy clone, StrategyId strategyId_) = factory.clone3StrategyAndRegister(
      owner, vault, globalRegistry, erc4626Vault, salt, tosData, guardianData, feesData, description
    );

    address cloneAddress = factory.addressOfClone3(salt);
    assertEq(cloneAddress, address(clone));
    _assertStrategyWasDeployedCorrectly(clone, strategyId_);
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
    assertEq(clone.description(), description);
  }
}

contract MockStrategyRegistry {
  function registerStrategy(address) external returns (StrategyId strategyId) {
    strategyId = StrategyId.wrap(1);
    IEarnStrategy(msg.sender).strategyRegistered(strategyId, IEarnStrategy(address(0)), "");
  }
}
