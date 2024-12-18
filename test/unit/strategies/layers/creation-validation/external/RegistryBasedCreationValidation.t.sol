// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import {
  ICreationValidationManagerCore,
  RegistryBasedCreationValidation,
  StrategyId,
  IGlobalEarnRegistry,
  IValidationManagersRegistryCore
} from "src/strategies/layers/creation-validation/external/RegistryBasedCreationValidation.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";

contract RegistryBasedCreationValidationTest is Test {
  RegistryBasedCreationValidationInstance private validation;
  IGlobalEarnRegistry private registry = IGlobalEarnRegistry(address(1));
  IValidationManagersRegistryCore private managersRegistry = IValidationManagersRegistryCore(address(2));
  ICreationValidationManagerCore private manager1 = ICreationValidationManagerCore(address(3));
  ICreationValidationManagerCore private manager2 = ICreationValidationManagerCore(address(4));
  StrategyId private strategyId = StrategyId.wrap(1);

  function setUp() public virtual {
    validation = new RegistryBasedCreationValidationInstance(registry, strategyId);
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, validation.VALIDATION_MANAGERS_REGISTRY()),
      abi.encode(managersRegistry)
    );
    vm.mockCall(
      address(managersRegistry),
      abi.encodeWithSelector(IValidationManagersRegistryCore.getManagers.selector, strategyId),
      abi.encode(_arrayOf(manager1, manager2))
    );
    vm.mockCall(
      address(manager1), abi.encodeWithSelector(ICreationValidationManagerCore.validatePositionCreation.selector), ""
    );
    vm.mockCall(
      address(manager2), abi.encodeWithSelector(ICreationValidationManagerCore.validatePositionCreation.selector), ""
    );
    vm.mockCall(
      address(managersRegistry),
      abi.encodeWithSelector(IValidationManagersRegistryCore.strategySelfConfigure.selector),
      abi.encode(_arrayOf(manager1, manager2))
    );
  }

  function test_init_revertWhen_invalidData() public {
    vm.expectRevert(abi.encodeWithSelector(RegistryBasedCreationValidation.InvalidData.selector));
    // We pass an array of bytes of length 1, while there are two managers
    validation.init(abi.encode("", new bytes[](1)));
  }

  function test_init() public {
    bytes memory registryData = "12345";
    bytes memory manager1Data = "67890";
    bytes memory manager2Data = "12345";
    bytes memory data = abi.encode(registryData, CommonUtils.arrayOf(manager1Data, manager2Data));
    vm.expectCall(
      address(managersRegistry),
      abi.encodeWithSelector(IValidationManagersRegistryCore.strategySelfConfigure.selector, registryData)
    );
    vm.expectCall(
      address(manager1),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, manager1Data)
    );
    vm.expectCall(
      address(manager2),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, manager2Data)
    );
    validation.init(data);
  }

  function test_validate_revertWhen_invalidData() public {
    vm.expectRevert(abi.encodeWithSelector(RegistryBasedCreationValidation.InvalidData.selector));
    // We pass an array of bytes of length 1, while there are two managers
    validation.validate(address(1), abi.encode(new bytes[](1)));
  }

  function test_validate() public {
    address toValidate = address(10);
    bytes memory manager1Data = "67890";
    bytes memory manager2Data = "12345";
    bytes memory data = abi.encode(CommonUtils.arrayOf(manager1Data, manager2Data));
    vm.expectCall(
      address(manager1),
      abi.encodeWithSelector(
        ICreationValidationManagerCore.validatePositionCreation.selector,
        strategyId,
        toValidate,
        address(this),
        manager1Data
      )
    );
    vm.expectCall(
      address(manager2),
      abi.encodeWithSelector(
        ICreationValidationManagerCore.validatePositionCreation.selector,
        strategyId,
        toValidate,
        address(this),
        manager2Data
      )
    );
    validation.validate(toValidate, data);
  }

  function _arrayOf(
    ICreationValidationManagerCore manager1_,
    ICreationValidationManagerCore manager2_
  )
    internal
    pure
    returns (ICreationValidationManagerCore[] memory array)
  {
    array = new ICreationValidationManagerCore[](2);
    array[0] = manager1_;
    array[1] = manager2_;
  }
}

contract RegistryBasedCreationValidationInstance is RegistryBasedCreationValidation {
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_) {
    _registry = registry;
    _strategyId = strategyId_;
  }

  function init(bytes calldata data) external initializer {
    _creationValidation_init(data);
  }

  function validate(address sender, bytes calldata signature) external {
    _creationValidation_validate(sender, signature);
  }

  function globalRegistry() public view virtual override returns (IGlobalEarnRegistry) {
    return _registry;
  }

  function strategyId() public view virtual override returns (StrategyId) {
    return _strategyId;
  }
}
