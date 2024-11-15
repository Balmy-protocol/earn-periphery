// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ICERC20 } from "./ICERC20.sol";

/// @notice Get up to date cToken data without mutating state.
/// @author Transmissions11 (https://github.com/transmissions11/libcompound)
library LibCompound {
  using Math for uint256;

  uint256 private constant WAD = 1e18;

  function viewUnderlyingBalanceOf(ICERC20 cToken, address user) internal view returns (uint256) {
    return cToken.balanceOf(user).mulDiv(viewExchangeRate(cToken), WAD, Math.Rounding.Floor);
  }

  function viewExchangeRate(ICERC20 cToken) internal view returns (uint256) {
    uint256 accrualBlockNumberPrior = cToken.accrualBlockNumber();

    // slither-disable-next-line incorrect-equality
    if (accrualBlockNumberPrior == block.number) {
      return cToken.exchangeRateStored();
    }

    uint256 totalCash = cToken.getCash();
    uint256 borrowsPrior = cToken.totalBorrows();
    uint256 reservesPrior = cToken.totalReserves();

    uint256 borrowRateMantissa = cToken.borrowRatePerBlock();

    require(borrowRateMantissa <= 0.0005e16, "RATE_TOO_HIGH"); // Same as borrowRateMaxMantissa in CTokenInterfaces.sol

    uint256 interestAccumulated =
      (borrowRateMantissa * (block.number - accrualBlockNumberPrior)).mulDiv(borrowsPrior, WAD, Math.Rounding.Floor);

    uint256 totalReserves =
      cToken.reserveFactorMantissa().mulDiv(interestAccumulated, WAD, Math.Rounding.Floor) + reservesPrior;
    uint256 totalBorrows = interestAccumulated + borrowsPrior;
    uint256 totalSupply = cToken.totalSupply();

    return totalSupply == 0
      ? cToken.initialExchangeRateMantissa()
      : (totalCash + totalBorrows - totalReserves).mulDiv(WAD, totalSupply, Math.Rounding.Floor);
  }
}
