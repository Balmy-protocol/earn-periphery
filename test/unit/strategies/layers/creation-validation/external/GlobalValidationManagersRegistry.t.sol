// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { Test } from "forge-std/Test.sol";
import {
  IValidationManagersRegistry,
  GlobalValidationManagersRegistry,
  StrategyId,
  ICreationValidationManagerCore,
  Ownable
} from "src/strategies/layers/creation-validation/external/GlobalValidationManagersRegistry.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";

contract GlobalValidationManagersRegistryTest is Test {
  address private owner = address(1);
  ICreationValidationManagerCore private initialManager1 = ICreationValidationManagerCore(address(2));
  ICreationValidationManagerCore private initialManager2 = ICreationValidationManagerCore(address(3));
  GlobalValidationManagersRegistry private registry;

  function setUp() public virtual {
    ICreationValidationManagerCore[] memory managers = _arrayOf(initialManager1, initialManager2);
    vm.expectEmit();
    emit IValidationManagersRegistry.ManagersSet(managers);
    registry = new GlobalValidationManagersRegistry(managers, owner);
  }

  function test_constructor() public {
    ICreationValidationManagerCore[] memory managers = registry.getManagers(StrategyId.wrap(0));
    assertEq(managers.length, 2);
    assertEq(address(managers[0]), address(initialManager1));
    assertEq(address(managers[1]), address(initialManager2));

    // Ownable
    assertEq(registry.owner(), owner);
  }

  function test_setManagers() public {
    ICreationValidationManagerCore newManager = ICreationValidationManagerCore(address(4));
    ICreationValidationManagerCore[] memory newManagers = _arrayOf(newManager);
    vm.expectEmit();
    emit IValidationManagersRegistry.ManagersSet(newManagers);
    vm.prank(owner);
    registry.setManagers(newManagers);
    ICreationValidationManagerCore[] memory managers = registry.getManagers(StrategyId.wrap(0));
    assertEq(managers.length, 1);
    assertEq(address(managers[0]), address(newManager));
  }

  function test_setManagers_revertsWhen_notOwner() public {
    ICreationValidationManagerCore newManager = ICreationValidationManagerCore(address(4));
    ICreationValidationManagerCore[] memory newManagers = _arrayOf(newManager);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    registry.setManagers(newManagers);
  }

  function test_strategySelfConfigure() public {
    ICreationValidationManagerCore[] memory managers = registry.strategySelfConfigure("");
    assertEq(managers.length, 2);
    assertEq(address(managers[0]), address(initialManager1));
    assertEq(address(managers[1]), address(initialManager2));
  }

  function _arrayOf(ICreationValidationManagerCore manager)
    internal
    pure
    returns (ICreationValidationManagerCore[] memory array)
  {
    array = new ICreationValidationManagerCore[](1);
    array[0] = manager;
  }

  function _arrayOf(
    ICreationValidationManagerCore manager1,
    ICreationValidationManagerCore manager2
  )
    internal
    pure
    returns (ICreationValidationManagerCore[] memory array)
  {
    array = new ICreationValidationManagerCore[](2);
    array[0] = manager1;
    array[1] = manager2;
  }
}
