// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { IDelayedWithdrawalAdapter } from "src/interfaces/IDelayedWithdrawalAdapter.sol";

struct RegisteredAdapter {
  IDelayedWithdrawalAdapter adapter;
  bool isNextFilled;
}

/// @notice A key composed of a position id and a token address
type PositionIdTokenKey is bytes32;

library RegisteredAdaptersLibrary {
  /// @notice Get all adapters for a position and token
  function get(
    mapping(uint256 => mapping(address => mapping(uint256 index => RegisteredAdapter registeredAdapter))) storage
      registeredAdapters,
    uint256 positionId,
    address token
  )
    internal
    view
    returns (mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapter)
  {
    return registeredAdapters[positionId][token];
  }

  /// @notice Checks if an adapter is repeated in the list of registered adapters for a position and token
  function isRepeated(
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters,
    IDelayedWithdrawalAdapter adapter
  )
    internal
    view
    returns (bool, uint256)
  {
    uint256 length = 0;
    bool shouldContinue = true;
    while (shouldContinue) {
      RegisteredAdapter memory adapterToCompare = registeredAdapters[length];
      if (adapterToCompare.adapter == adapter) {
        // Since we won't be using the length, we can return any value
        return (true, 0);
      }
      if (address(adapterToCompare.adapter) != address(0)) {
        unchecked {
          ++length;
        }
      }
      shouldContinue = adapterToCompare.isNextFilled;
    }

    return (false, length);
  }

  function set(
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters,
    uint256 index,
    IDelayedWithdrawalAdapter adapter
  )
    internal
  {
    if (index != 0) registeredAdapters[index - 1].isNextFilled = true;
    registeredAdapters[index] = RegisteredAdapter({ adapter: adapter, isNextFilled: false });
  }

  function pop(
    mapping(uint256 index => RegisteredAdapter registeredAdapter) storage registeredAdapters,
    uint256 start,
    uint256 end
  )
    internal
  {
    for (uint256 i = start; i < end; ++i) {
      delete registeredAdapters[i];
    }
  }
}
