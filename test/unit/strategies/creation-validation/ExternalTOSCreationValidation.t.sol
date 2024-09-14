// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import {
  ITOSManager,
  ExternalTOSCreationValidation,
  StrategyId,
  IGlobalEarnRegistry
} from "src/strategies/creation-validation/ExternalTOSCreationValidation.sol";

contract ExternalTOSCreationValidationTest is Test {
  bytes32 private constant GROUP_1 = keccak256("group1");
  ExternalTOSCreationValidationInstance private tosValidation;
  IGlobalEarnRegistry private registry = IGlobalEarnRegistry(address(1));
  ITOSManager private manager = ITOSManager(address(2));
  StrategyId private strategyId = StrategyId.wrap(1);
  VmSafe.Wallet private alice = vm.createWallet("alice");

  function setUp() public virtual {
    tosValidation = new ExternalTOSCreationValidationInstance(registry, strategyId);
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector),
      abi.encode(manager)
    );
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ITOSManager.assignStrategyToGroup.selector),
      abi.encode()
    );
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ITOSManager.validatePositionCreation.selector),
      abi.encode()
    );
  }

  function test_init() public {
    vm.expectCall(
      address(manager), abi.encodeWithSelector(ITOSManager.strategySelfConfigure.selector, abi.encode(GROUP_1))
    );
    tosValidation.init(abi.encode(GROUP_1));
  }

  function test_validate() public {
    address sender = address(10);
    bytes memory signature = "my signature";
    vm.expectCall(
      address(manager),
      abi.encodeWithSelector(ITOSManager.validatePositionCreation.selector, strategyId, sender, signature)
    );
    tosValidation.validate(sender, signature);
  }
}

contract ExternalTOSCreationValidationInstance is ExternalTOSCreationValidation {
  IGlobalEarnRegistry private _registry;
  StrategyId private _strategyId;

  constructor(IGlobalEarnRegistry registry, StrategyId strategyId_) {
    _registry = registry;
    _strategyId = strategyId_;
  }

  function init(bytes calldata data) external initializer {
    _creationValidation_init(data);
  }

  function validate(address sender, bytes calldata signature) external view {
    _creationValidation_validate(sender, signature);
  }

  function globalRegistry() public view virtual override returns (IGlobalEarnRegistry) {
    return _registry;
  }

  function strategyId() public view virtual override returns (StrategyId) {
    return _strategyId;
  }
}
