// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { DelayedWithdrawalAdapterDead } from "./DelayedWithdrawalAdapterDead.sol";
import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract ERC4626DelayedWithdrawalAdapterMock is DelayedWithdrawalAdapterDead {
  mapping(uint256 positionId => mapping(address token => uint256 withdrawn)) private _withdrawnFunds;
  mapping(uint256 positionId => mapping(address token => uint256 pending)) private _pendingFunds;
  address private farmToken;

  constructor(address _farmToken) DelayedWithdrawalAdapterDead() {
    farmToken = _farmToken;
  }

  function estimatedPendingFunds(uint256 positionId, address token) public view virtual override returns (uint256) {
    return IERC4626(farmToken).previewRedeem(_pendingFunds[positionId][token]);
  }

  function withdrawableFunds(uint256 positionId, address token) public view virtual override returns (uint256) {
    return IERC4626(farmToken).previewRedeem(_pendingFunds[positionId][token] - _withdrawnFunds[positionId][token]);
  }

  function initiateDelayedWithdrawal(uint256 positionId, address token, uint256 shares) external virtual override {
    _pendingFunds[positionId][token] += shares;
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
    _withdrawnFunds[positionId][token] += IERC4626(farmToken).previewWithdraw(_pendingFunds[positionId][token]);
    withdrawn = withdrawableFunds(positionId, token);
    stillPending = estimatedPendingFunds(positionId, token);
  }
}
