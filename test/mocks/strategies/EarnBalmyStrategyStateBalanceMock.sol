// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IEarnBalmyStrategy, IDelayedWithdrawalAdapter } from "src/interfaces/IEarnBalmyStrategy.sol";
import {
  EarnStrategyStateBalanceMock,
  IEarnStrategy,
  IERC165
} from "@balmy/earn-core-test/mocks/strategies/EarnStrategyStateBalanceMock.sol";

import { DelayedWithdrawalAdapterMock } from "test/mocks/delayed-withdrawal-adapter/DelayedWithdrawalAdapterMock.sol";

/// @notice An implementation of IEarnBalmyStrategy that returns balances by reading token's state
contract EarnBalmyStrategyStateBalanceMock is EarnStrategyStateBalanceMock, IEarnBalmyStrategy {
  mapping(address token => IDelayedWithdrawalAdapter adapter) public override delayedWithdrawalAdapter;

  constructor(
    address[] memory tokens_,
    WithdrawalType[] memory withdrawalTypes_
  )
    EarnStrategyStateBalanceMock(tokens_, withdrawalTypes_)
  {
    for (uint256 i; i < tokens_.length; ++i) {
      delayedWithdrawalAdapter[tokens_[i]] = new DelayedWithdrawalAdapterMock();
    }
  }

  function supportsInterface(bytes4 interfaceId)
    external
    pure
    override(EarnStrategyStateBalanceMock, IERC165)
    returns (bool)
  {
    return interfaceId == type(IEarnBalmyStrategy).interfaceId || interfaceId == type(IEarnStrategy).interfaceId
      || interfaceId == type(IERC165).interfaceId;
  }
}
