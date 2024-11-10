// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import {
  ILidoSTETHQueue,
  WithdrawalRequestStatus
} from "src/strategies/layers/connector/lido/LidoSTETHDelayedWithdrawalAdapter.sol";

contract LidoSTETHQueueMock is ILidoSTETHQueue {
  bool internal timeToWithdraw = false;
  uint256 internal amountPending = 0;

  receive() external payable { }

  function requestWithdrawals(
    uint256[] memory amounts,
    address
  )
    external
    override
    returns (uint256[] memory requestIds)
  {
    requestIds = new uint256[](1);
    requestIds[0] = 1;
    amountPending += amounts[0];
  }

  function getWithdrawalStatus(uint256[] memory _requestIds)
    external
    view
    override
    returns (WithdrawalRequestStatus[] memory statuses)
  {
    if (_requestIds.length == 0) {
      return new WithdrawalRequestStatus[](0);
    }
    statuses = new WithdrawalRequestStatus[](1);
    statuses[0] = WithdrawalRequestStatus(amountPending, 1, address(this), 0, timeToWithdraw, false);
  }

  function claimWithdrawalsTo(uint256[] memory, uint256[] memory, address _recipient) external override {
    payable(_recipient).transfer(amountPending);
    // solhint-disable-next-line reentrancy
    amountPending = 0;
  }

  function setTimeToWithdraw(bool _timeToWithdraw) public {
    timeToWithdraw = _timeToWithdraw;
  }

  function findCheckpointHints(
    uint256[] memory _requestIds,
    uint256 _firstIndex,
    uint256 _lastIndex
  )
    external
    view
    override
    returns (uint256[] memory hintIds)
  // solhint-disable-next-line no-empty-blocks
  { }
}
