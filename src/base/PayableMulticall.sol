// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @dev Adding this contract will enable batching calls. This is basically the same as Open Zeppelin's
 *      Multicall contract, but we have made it payable. It supports both payable and non payable
 *      functions. However, if `msg.value` is not zero, then non payable functions cannot be called.
 *      Any contract that uses this Multicall version should be very careful when using msg.value.
 *      For more context, read: https://github.com/Uniswap/v3-periphery/issues/52
 */
abstract contract PayableMulticall {
  /**
   * @notice Receives and executes a batch of function calls on this contract.
   * @param data A list of different function calls to execute
   * @return results The result of executing each of those calls
   */
  function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
    results = new bytes[](data.length);
    for (uint256 i = 0; i < data.length; ++i) {
      results[i] = Address.functionDelegateCall(address(this), data[i]);
    }
    return results;
  }
}
