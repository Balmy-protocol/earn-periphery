// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IDelayedWithdrawalAdapter } from "./IDelayedWithdrawalAdapter.sol";

/// @notice Interface for Earn strategies that support delayed withdrawals
interface IEarnBalmyStrategy is IEarnStrategy {
  /**
   * @notice Returns the "delayed withdrawal" adapter that will be used for the given token
   * @param token The token to use the adapter for
   * @return The address of the "delayed withdrawal" adapter, or the zero address if none is configured
   */
  function delayedWithdrawalAdapter(address token) external view returns (IDelayedWithdrawalAdapter);
}
