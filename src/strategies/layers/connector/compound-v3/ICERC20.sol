// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICERC20 is IERC20 {
  struct TotalsBasic {
    // 1st slot
    uint64 baseSupplyIndex;
    uint64 baseBorrowIndex;
    uint64 trackingSupplyIndex;
    uint64 trackingBorrowIndex;
    // 2nd slot
    uint104 totalSupplyBase;
    uint104 totalBorrowBase;
    uint40 lastAccrualTime;
    uint8 pauseFlags;
  }

  struct UserBasic {
    int104 principal;
    uint64 baseTrackingIndex;
    uint64 baseTrackingAccrued;
    uint16 assetsIn;
    uint8 _reserved;
  }

  function baseScale() external view returns (uint256);
  function totalsBasic() external view returns (TotalsBasic memory);
  function baseMinForRewards() external view returns (uint256);
  function trackingIndexScale() external view returns (uint256);
  function baseTrackingSupplySpeed() external view returns (uint256);
  function baseTrackingBorrowSpeed() external view returns (uint256);
  function userBasic(address account) external view returns (UserBasic memory);
  function supply(address asset, uint256 amount) external;
  function withdraw(address asset, uint256 amount) external;
}
