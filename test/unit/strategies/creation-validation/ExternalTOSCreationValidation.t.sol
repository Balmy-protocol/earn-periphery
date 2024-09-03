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
  IGlobalEarnRegistry registry = IGlobalEarnRegistry(address(1));
  ITOSManager manager = ITOSManager(address(2));
  StrategyId strategyId = StrategyId.wrap(1);
  VmSafe.Wallet private alice = vm.createWallet("alice");

  function setUp() public virtual {
    tosValidation = new ExternalTOSCreationValidationInstance(registry, strategyId);
    vm.mockCall(
      address(registry),
      abi.encodeWithSelector(IGlobalEarnRegistry.getAddressOrFail.selector, keccak256("TOS_MANAGER")),
      abi.encode(manager)
    );
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ITOSManager.assignStrategyToGroup.selector, keccak256("TOS_MANAGER")),
      abi.encode()
    );
    vm.mockCall(
      address(manager),
      abi.encodeWithSelector(ITOSManager.validatePositionCreation.selector, keccak256("TOS_MANAGER")),
      abi.encode()
    );
  }

  function test_init_emptyGroup() public {
    // When group is empty, no TOS manager is not called
    vm.expectCall(address(manager), abi.encodeWithSelector(ITOSManager.assignStrategyToGroup.selector), 0);
    tosValidation.init(bytes32(0));
  }

  function test_init() public {
    // When group is set, TOS manager is called
    vm.expectCall(
      address(manager), abi.encodeWithSelector(ITOSManager.assignStrategyToGroup.selector, strategyId, GROUP_1)
    );
    tosValidation.init(GROUP_1);
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

  function init(bytes32 tosGroup) external initializer {
    _creationValidation_init(tosGroup);
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
