// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Test } from "forge-std/Test.sol";
import { Clone } from "src/strategies/instances/base/Clone.sol";

contract CloneTest is Test {
  uint256 private uint256Arg = 12_345_677_990;
  address private addressArg = 0xDb2ca0d78d78F304465e83578DE3DdBA613c79D9;
  MyClone private clone;

  function setUp() public virtual {
    MyClone implementation = new MyClone();
    bytes memory immutableArgs = abi.encodePacked(uint256Arg, addressArg);
    clone = MyClone(Clones.cloneWithImmutableArgs(address(implementation), immutableArgs));
  }

  function test_uint256Arg() public {
    assertEq(clone.getUint(), uint256Arg);
  }

  function test_addressArg() public {
    assertEq(clone.getAddress(), addressArg);
  }
}

contract MyClone is Clone {
  // Immutable params:
  // 1. uint256 (32B) - _getArgUint256(0)
  // 2. address (20B) - _getArgAddress(32)

  function getUint() public view returns (uint256) {
    return _getArgUint256(0);
  }

  function getAddress() public view returns (address) {
    return _getArgAddress(32);
  }
}
