// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICERC20 is IERC20 {
  function supply(address asset, uint256 amount) external;
  function withdraw(address asset, uint256 amount) external;
}
