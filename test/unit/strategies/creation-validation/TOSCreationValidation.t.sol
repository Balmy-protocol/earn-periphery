// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { TOSCreationValidation } from "src/strategies/creation-validation/TOSCreationValidation.sol";

contract TOSCreationValidationTest is Test {
  event TOSUpdated(bytes tos, address sender);

  TOSCreationValidationInstance private tosValidation;
  bytes private tos = "this are the terms of service";
  address private admin = address(1);
  VmSafe.Wallet private alice = vm.createWallet("alice");

  function setUp() public virtual {
    vm.expectEmit();
    emit TOSUpdated(tos, address(this));
    tosValidation = new TOSCreationValidationInstance(tos, admin);
  }

  function test_constructor() public {
    assertEq(tosValidation.tosHash(), MessageHashUtils.toEthSignedMessageHash(tos));
  }

  function test_supportsInterface() public {
    assertTrue(tosValidation.supportsInterface(type(IAccessControl).interfaceId));
  }

  function test_setTOS() public {
    vm.prank(admin);
    vm.expectEmit();
    emit TOSUpdated("new tos", admin);
    tosValidation.setTOS("new tos");
    assertEq(tosValidation.tosHash(), MessageHashUtils.toEthSignedMessageHash(bytes("new tos")));
  }

  function test_setTOS_revertWhen_calledWithoutRole() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), tosValidation.TOS_UPDATE_ROLE()
      )
    );
    tosValidation.setTOS("new tos");
  }

  function test_validate_tosIsSet_signature() public {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice, tosValidation.tosHash());
    bytes memory signature = abi.encodePacked(r, s, v);
    tosValidation.validate(alice.addr, signature);
  }

  function test_validate_tosIsSet_ERC1271() public {
    bytes memory signature = "my signature";
    MyContract caller = new MyContract(tosValidation.tosHash(), signature);
    tosValidation.validate(address(caller), signature);
  }

  function test_validate_tosIsNotSet() public {
    TOSCreationValidationInstance validation = new TOSCreationValidationInstance("", admin);
    // Since TOS is empty, signature can be anything
    validation.validate(address(0), "");
  }

  function test_validate_revertWhen_signatureIsInvalid() public {
    vm.expectRevert(abi.encodeWithSelector(TOSCreationValidation.InvalidTOSSignature.selector));
    tosValidation.validate(alice.addr, "");
  }
}

contract TOSCreationValidationInstance is TOSCreationValidation {
  constructor(bytes memory tos, address admin) TOSCreationValidation(tos) {
    _grantRole(TOS_UPDATE_ROLE, admin);
  }

  function validate(address sender, bytes calldata signature) external view {
    _creationValidation_validate(sender, signature);
  }
}

contract MyContract is IERC1271 {
  bytes32 private _expectedHash;
  bytes private _expectedSignature;

  constructor(bytes32 expectedHash, bytes memory expectedSignature) {
    _expectedHash = expectedHash;
    _expectedSignature = expectedSignature;
  }

  function isValidSignature(bytes32 hash, bytes memory signature) external view override returns (bytes4 magicValue) {
    return
      hash == _expectedHash && keccak256(signature) == keccak256(_expectedSignature) ? bytes4(0x1626ba7e) : bytes4(0x0);
  }
}
