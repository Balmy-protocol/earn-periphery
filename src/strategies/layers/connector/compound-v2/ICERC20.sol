// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICERC20 is IERC20 {
  function mint(uint256 underlyingAmount) external returns (uint256);
  function redeemUnderlying(uint256 underlyingAmount) external returns (uint256);
  function exchangeRateStored() external view returns (uint256);
  function decimals() external view returns (uint256);
  function getCash() external view returns (uint256);
  function totalReserves() external view returns (uint256);
  function totalBorrows() external view returns (uint256);
  function accrualBlockNumber() external view returns (uint256);
  function borrowRatePerBlock() external view returns (uint256);
  function reserveFactorMantissa() external view returns (uint256);
  function initialExchangeRateMantissa() external view returns (uint256);
}
