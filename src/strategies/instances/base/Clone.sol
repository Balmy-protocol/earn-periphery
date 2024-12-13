// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract Clone {
  /// @notice Reads an immutable arg with type address
  /// @param argOffset The offset of the arg in the packed data
  /// @return arg The arg value
  function _getArgAddress(uint256 argOffset) internal view returns (address arg) {
    return address(uint160(bytes20(_getArg(argOffset, 20))));
  }

  /// @notice Reads an immutable arg with type uint256
  /// @param argOffset The offset of the arg in the packed data
  /// @return arg The arg value
  function _getArgUint256(uint256 argOffset) internal view returns (uint256 arg) {
    return uint256(bytes32(_getArg(argOffset, 32)));
  }

  /// @notice Reads an immutable arg
  /// @param argOffset The offset of the arg in the packed data
  /// @param argLength The length of the arg in the packed data
  /// @return arg The arg value as bytes
  function _getArg(uint256 argOffset, uint256 argLength) private view returns (bytes memory arg) {
    arg = new bytes(argLength);
    assembly {
      extcodecopy(address(), add(arg, 32), add(45, argOffset), argLength)
    }
  }
}
