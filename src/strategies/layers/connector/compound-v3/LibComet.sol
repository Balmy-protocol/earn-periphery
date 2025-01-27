// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ICERC20 } from "./ICERC20.sol";
import { ICometRewards } from "./ICometRewards.sol";

/// @notice Comet (Compound V3) doesn't have a way to calculate rewards owed without modifying the storage, so we are
///         now building a library provides this functionality. This library interacts with both Comet and Rewards
///         contracts and then attempts to replicate their logic, but without modifying the storage.

library LibComet {
  error InvalidUInt64();

  struct GlobalData {
    // In totals basic
    uint256 lastAccrualTime;
    uint256 totalSupplyBase;
    uint256 trackingSupplyIndex;
    uint256 totalBorrowBase;
    uint256 trackingBorrowIndex;
    // Separately stored
    uint256 baseTrackingSupplySpeed;
    uint256 baseTrackingBorrowSpeed;
    uint256 baseScale;
    uint256 baseMinForRewards;
    uint256 trackingIndexScale;
  }

  uint256 private constant FACTOR_SCALE = 1e18;
  uint64 private constant BASE_ACCRUAL_SCALE = 1e6;

  /**
   * @notice Calculates the rewards owed to an account without modifying the storage.
   * @param rewards The Comet Rewards contract
   * @param comet The Comet contract
   * @param account The account to calculate rewards for
   * @return rewardToken The token of the rewards (or the zero address if there are no rewards)
   * @return rewardAmount The amount of rewards owed
   */
  function getRewardsOwed(
    ICometRewards rewards,
    ICERC20 comet,
    address account
  )
    internal
    view
    returns (address rewardToken, uint256 rewardAmount)
  {
    ICometRewards.RewardConfig memory config = _getRewardsConfig(rewards, comet);
    if (config.token == address(0)) {
      return (address(0), 0);
    }

    uint256 claimed = rewards.rewardsClaimed(address(comet), account);
    uint256 accrued = _getRewardAccrued(comet, account, config);

    uint256 owed = accrued > claimed ? accrued - claimed : 0;
    return (config.token, owed);
  }

  function _getRewardsConfig(
    ICometRewards rewards,
    ICERC20 comet
  )
    private
    view
    returns (ICometRewards.RewardConfig memory)
  {
    (bytes memory result) = Address.functionStaticCall(
      address(rewards), abi.encodeWithSelector(ICometRewards.rewardConfig.selector, address(comet))
    );
    if (result.length == 96) {
      // Some versions of the rewards contract don't have the multiplier field, so we need to handle that here
      ICometRewards.LegacyRewardConfig memory config = abi.decode(result, (ICometRewards.LegacyRewardConfig));
      return ICometRewards.RewardConfig({
        token: config.token,
        rescaleFactor: config.rescaleFactor,
        shouldUpscale: config.shouldUpscale,
        multiplier: 1e18
      });
    }
    return abi.decode(result, (ICometRewards.RewardConfig));
  }

  function _getRewardAccrued(
    ICERC20 comet,
    address account,
    ICometRewards.RewardConfig memory config
  )
    private
    view
    returns (uint256)
  {
    ICERC20.UserBasic memory basic = _accrueAccount(comet, account);
    uint256 accrued = basic.baseTrackingAccrued;

    if (config.shouldUpscale) {
      accrued *= config.rescaleFactor;
    } else {
      // slither-disable-next-line divide-before-multiply
      accrued /= config.rescaleFactor;
    }
    return accrued * config.multiplier / FACTOR_SCALE;
  }

  function _getAllGlobalData(ICERC20 comet) private view returns (GlobalData memory globalData) {
    ICERC20.TotalsBasic memory totalsBasic = comet.totalsBasic();
    globalData.lastAccrualTime = totalsBasic.lastAccrualTime;
    globalData.totalSupplyBase = totalsBasic.totalSupplyBase;
    globalData.trackingSupplyIndex = totalsBasic.trackingSupplyIndex;
    globalData.totalBorrowBase = totalsBasic.totalBorrowBase;
    globalData.trackingBorrowIndex = totalsBasic.trackingBorrowIndex;
    globalData.baseTrackingSupplySpeed = comet.baseTrackingSupplySpeed();
    globalData.baseTrackingBorrowSpeed = comet.baseTrackingBorrowSpeed();
    globalData.baseScale = comet.baseScale();
    globalData.baseMinForRewards = comet.baseMinForRewards();
    globalData.trackingIndexScale = comet.trackingIndexScale();
  }

  function _accrueAccount(ICERC20 comet, address account) private view returns (ICERC20.UserBasic memory basic) {
    GlobalData memory globalData = _getAllGlobalData(comet);
    _accrueInternal(globalData);
    basic = comet.userBasic(account);
    _updateBasePrincipal(globalData, basic);
  }

  // slither-disable-next-line timestamp
  function _accrueInternal(GlobalData memory globalData) internal view {
    uint256 timeElapsed = block.timestamp - globalData.lastAccrualTime;
    if (timeElapsed > 0) {
      if (globalData.totalSupplyBase >= globalData.baseMinForRewards) {
        globalData.trackingSupplyIndex += _safe64(
          _divBaseWei(
            globalData.baseTrackingSupplySpeed * timeElapsed, globalData.baseScale, globalData.totalSupplyBase
          )
        );
      }
      if (globalData.totalBorrowBase >= globalData.baseMinForRewards) {
        globalData.trackingBorrowIndex += _safe64(
          _divBaseWei(
            globalData.baseTrackingBorrowSpeed * timeElapsed, globalData.baseScale, globalData.totalBorrowBase
          )
        );
      }
    }
  }

  function _updateBasePrincipal(GlobalData memory globalData, ICERC20.UserBasic memory basic) private pure {
    int104 principal = basic.principal;
    uint256 accrualDescaleFactor = globalData.baseScale / BASE_ACCRUAL_SCALE;

    if (principal >= 0) {
      uint256 indexDelta = uint256(globalData.trackingSupplyIndex - basic.baseTrackingIndex);
      basic.baseTrackingAccrued +=
        _safe64(uint104(principal) * indexDelta / globalData.trackingIndexScale / accrualDescaleFactor);
    } else {
      uint256 indexDelta = uint256(globalData.trackingBorrowIndex - basic.baseTrackingIndex);
      basic.baseTrackingAccrued +=
        _safe64(uint104(-principal) * indexDelta / globalData.trackingIndexScale / accrualDescaleFactor);
    }
  }

  function _divBaseWei(uint256 n, uint256 baseScale, uint256 baseWei) private pure returns (uint256) {
    return n * baseScale / baseWei;
  }

  // slither-disable-next-line timestamp
  function _safe64(uint256 n) private pure returns (uint64) {
    if (n > type(uint64).max) revert InvalidUInt64();
    return uint64(n);
  }
}
