// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { DelayedWithdrawalAdapterDead } from "./DelayedWithdrawalAdapterDead.sol";

contract DelayedWithdrawalAdapterMock is DelayedWithdrawalAdapterDead {
  mapping(uint256 positionId => mapping(address token => uint256 withdrawn)) private _withdrawnFunds;
  mapping(uint256 positionId => mapping(address token => uint256 pending)) private _pendingFunds;

  function estimatedPendingFunds(uint256 positionId, address token) public view virtual override returns (uint256) {
    return _pendingFunds[positionId][token];
  }

  function withdrawableFunds(uint256 positionId, address token) public view virtual override returns (uint256) {
    return positionId - _withdrawnFunds[positionId][token];
  }

  function initiateDelayedWithdrawal(uint256 positionId, address token, uint256 amount) external virtual override {
    _pendingFunds[positionId][token] += amount;
  }

  function withdraw(
    uint256 positionId,
    address token,
    address
  )
    external
    virtual
    override
    returns (uint256 withdrawn, uint256 stillPending)
  {
    _withdrawnFunds[positionId][token] += withdrawn = withdrawableFunds(positionId, token);
    stillPending = estimatedPendingFunds(positionId, token);
  }
}
