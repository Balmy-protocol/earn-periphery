// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

interface ICometRewards {
  struct RewardConfig {
    address token;
    uint64 rescaleFactor;
    bool shouldUpscale;
    // This multiplier is not present in all versions of the rewards contract
    uint256 multiplier;
  }

  struct LegacyRewardConfig {
    address token;
    uint64 rescaleFactor;
    bool shouldUpscale;
  }

  struct RewardOwed {
    address token;
    uint256 owed;
  }

  function rewardConfig(address comet) external view returns (RewardConfig memory);
  function rewardsClaimed(address comet, address account) external view returns (uint256);
  function getRewardOwed(address comet, address account) external returns (RewardOwed memory);
  function claim(address comet, address src, bool shouldAccrue) external;
  function claimTo(address comet, address src, address to, bool shouldAccrue) external;
}
