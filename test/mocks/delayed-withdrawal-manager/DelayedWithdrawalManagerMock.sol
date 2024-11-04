// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IDelayedWithdrawalManager, IEarnVault } from "src/interfaces/IDelayedWithdrawalManager.sol";

contract DelayedWithdrawalManagerMock is IDelayedWithdrawalManager {
  // solhint-disable-next-line no-empty-blocks
  function estimatedPendingFunds(uint256 positionId, address token) external view override returns (uint256) { }

  // solhint-disable-next-line no-empty-blocks
  function withdrawableFunds(uint256 positionId, address token) external view override returns (uint256) { }

  function allPositionFunds(uint256 positionId)
    external
    view
    override
    returns (address[] memory tokens, uint256[] memory estimatedPending, uint256[] memory withdrawable)
  // solhint-disable-next-line no-empty-blocks
  { }

  // solhint-disable-next-line no-empty-blocks
  function registerDelayedWithdraw(uint256 positionId, address token) external override { }

  function withdraw(
    uint256 positionId,
    address token,
    address recipient
  )
    external
    override
    returns (uint256 withdrawn, uint256 stillPending)
  // solhint-disable-next-line no-empty-blocks
  { }

  // solhint-disable-next-line no-empty-blocks
  function VAULT() external view override returns (IEarnVault) { }
}
