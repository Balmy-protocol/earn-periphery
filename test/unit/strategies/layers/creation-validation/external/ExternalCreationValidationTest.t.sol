// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import {
  ICreationValidationManagerCore,
  ExternalCreationValidation,
  StrategyId,
  IGlobalEarnRegistry
} from "src/strategies/layers/creation-validation/external/ExternalCreationValidation.sol";

contract ExternalCreationValidationTest is Test {
  bytes32 private constant GROUP_1 = keccak256("group1");
  bytes32 private constant VALIDATION_MANAGER_KEY = keccak256("validationManagerKey");
  ExternalCreationValidationInstance private validation;
  IGlobalEarnRegistry private registry = IGlobalEarnRegistry(address(1));
  ICreationValidationManagerCore private manager = ICreationValidationManagerCore(address(2));
  StrategyId private strategyId = StrategyId.wrap(1);

  function setUp() public virtual {
    validation = new ExternalCreationValidationInstance(registry, strategyId, VALIDATION_MANAGER_KEY);
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, VALIDATION_MANAGER_KEY),
      abi.encode(manager)
    );
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ICreationValidationManagerCore.validatePositionCreation.selector),
      abi.encode()
    );
  }

  function test_init() public {
    vm.expectCall(
      address(manager),
      abi.encodeWithSelector(ICreationValidationManagerCore.strategySelfConfigure.selector, abi.encode(GROUP_1))
    );
    validation.init(abi.encode(GROUP_1));
  }

  function test_validate() public {
    address sender = address(10);
    bytes memory signature = "my signature";
    vm.expectCall(
      address(manager),
      abi.encodeWithSelector(
        ICreationValidationManagerCore.validatePositionCreation.selector, strategyId, sender, address(this), signature
      )
    );
    validation.validate(sender, signature);
  }
}

contract ExternalCreationValidationInstance is ExternalCreationValidation {
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;
  bytes32 private _validationManagerKey;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_, bytes32 validationManagerKey_) {
    _registry = registry;
    _strategyId = strategyId_;
    _validationManagerKey = validationManagerKey_;
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

  function validationManagerKey() public view virtual override returns (bytes32) {
    return _validationManagerKey;
  }
}
