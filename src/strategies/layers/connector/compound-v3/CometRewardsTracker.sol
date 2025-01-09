// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { ICometRewards, ICERC20, LibComet } from "./LibComet.sol";

/// @notice This contract uses the LibComet library to calculate the rewards owed to an account without modifying the
///         storage. Contracts can use this contract directly instead of using the LibComet library, saving quite a bit
///         of bytecode size.
contract CometRewardsTracker {
  function getRewardsOwed(
    ICometRewards rewards,
    ICERC20 comet,
    address account
  )
    public
    view
    returns (address rewardToken, uint256 rewardAmount)
  {
    return LibComet.getRewardsOwed(rewards, comet, account);
  }

  /// @dev These errors are meant to be used only for testing and debugging purposes.
  error RewardTokensAreNotTheSame(address libVersion, address directVersion);
  error RewardAmountsAreNotTheSame(uint256 libVersion, uint256 directVersion);

  /// @dev This function is meant to be used only for testing and debugging purposes.
  function compareVersions(ICometRewards rewards, ICERC20 comet, address account) external returns (bool) {
    (address rewardToken, uint256 rewardAmount) = getRewardsOwed(rewards, comet, account);
    ICometRewards.RewardOwed memory owed = rewards.getRewardOwed(address(comet), account);
    if (owed.token != rewardToken) {
      revert RewardTokensAreNotTheSame(rewardToken, owed.token);
    }
    if (owed.owed != rewardAmount) {
      revert RewardAmountsAreNotTheSame(owed.owed, rewardAmount);
    }
    return true;
  }
}
