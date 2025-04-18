// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

interface IUniversalRewardsDistributor {
  function claim(
    address account,
    address reward,
    uint256 claimable,
    bytes32[] calldata proof
  )
    external
    returns (uint256 amount);
}
