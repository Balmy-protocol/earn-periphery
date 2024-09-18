// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

library StrategyHelper {
  function areAllImmediate(IEarnStrategy.WithdrawalType[] memory types) internal pure returns (bool) {
    for (uint256 i; i < types.length; ++i) {
      if (types[i] != IEarnStrategy.WithdrawalType.IMMEDIATE) {
        return false;
      }
    }
    return true;
  }
}
