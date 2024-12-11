// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  BaseConnector,
  IEarnStrategy,
  SpecialWithdrawalCode,
  IDelayedWithdrawalAdapter,
  StrategyId
} from "../base/BaseConnector.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { ICERC20 } from "./ICERC20.sol";
import { CometHelpers } from "./CometHelpers.sol";

interface ICometRewards {
  struct RewardConfig {
    address token;
    uint64 rescaleFactor;
    bool shouldUpscale;
  }

  struct RewardOwed {
    address token;
    uint256 owed;
  }

  function rewardConfig(address) external view returns (RewardConfig memory);
  function claim(address comet, address src, bool shouldAccrue) external;
  function claimTo(address comet, address src, address to, bool shouldAccrue) external;
}

interface CometExt {
  function totalsBasic() external view returns (TotalsBasic memory);
}

struct TotalsBasic {
  uint64 baseSupplyIndex;
  uint64 baseBorrowIndex;
  uint64 trackingSupplyIndex;
  uint64 trackingBorrowIndex;
  uint104 totalSupplyBase;
  uint104 totalBorrowBase;
  uint40 lastAccrualTime;
  uint8 pauseFlags;
}

abstract contract CompoundV3Connector is BaseConnector, Initializable, CometHelpers {
  using SafeERC20 for IERC20;
  using Math for uint256;
  using Token for address;

  /// @notice Returns the cToken's address
  function cToken() public view virtual returns (ICERC20);
  /// @notice Returns the rewards controller
  function cometRewards() public view virtual returns (ICometRewards);

  function _asset() internal view virtual returns (address);

  /// @notice Performs a max approve to the cToken, so that we can deposit without any worries
  function maxApproveCToken() public {
    address asset = _asset();
    IERC20(asset).forceApprove(address(cToken()), type(uint256).max);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_init() internal onlyInitializing {
    maxApproveCToken();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_asset() internal view virtual override returns (address) {
    return _asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_allTokens() internal view virtual override returns (address[] memory tokens) {
    tokens = new address[](2);
    tokens[0] = _connector_asset();
    tokens[1] = address(cometRewards().rewardConfig(address(cToken())).token);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isDepositTokenSupported(address depositToken) internal view virtual override returns (bool) {
    return depositToken == _connector_asset() || depositToken == address(cToken());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal view virtual override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(cToken());
  }

  // revisar
  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxDeposit(address depositToken) internal view virtual override returns (uint256) {
    if (!_connector_isDepositTokenSupported(depositToken)) {
      revert InvalidDepositToken(depositToken);
    }
    return type(uint256).max;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedWithdrawals()
    internal
    view
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return new IEarnStrategy.WithdrawalType[](2); // IMMEDIATE
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isSpecialWithdrawalSupported(SpecialWithdrawalCode withdrawalCode)
    internal
    view
    virtual
    override
    returns (bool)
  {
    return withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT
      || withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedSpecialWithdrawals()
    internal
    view
    virtual
    override
    returns (SpecialWithdrawalCode[] memory codes)
  {
    codes = new SpecialWithdrawalCode[](2);
    codes[0] = SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT;
    codes[1] = SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT;
  }

  // revisar
  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxWithdraw()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    (tokens, withdrawable) = _connector_totalBalances();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_totalBalances()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    //ICometRewards.RewardConfig memory config = cometRewards().rewardConfig(address(cToken())); // TODO: calculate
    // rewards
    tokens = _connector_allTokens();
    balances = new uint256[](2);
    balances[0] = underlyingBalance();
    balances[1] = 0; // TODO: calculate rewards
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_delayedWithdrawalAdapter(address)
    internal
    view
    virtual
    override
    returns (IDelayedWithdrawalAdapter)
  {
    return IDelayedWithdrawalAdapter(address(0));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_deposited(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    override
    returns (uint256 assetsDeposited)
  {
    if (depositToken == _connector_asset()) {
      uint256 balanceBefore = underlyingBalance();

      cToken().supply(depositToken, convertToShares(depositAmount));

      uint256 balanceAfter = underlyingBalance();
      return balanceAfter - balanceBefore;
    } else if (depositToken == address(cToken())) {
      return convertToAssets(depositAmount);
    } else {
      revert InvalidDepositToken(depositToken);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_withdraw(
    uint256,
    address[] memory,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    uint256 shares = convertToShares(toWithdraw[0]);
    if (shares > 0) {
      address asset = _asset();
      cToken().withdraw(asset, shares);
      asset.transfer({ recipient: recipient, amount: toWithdraw[0] });
    }
    IERC20 rewardToken = IERC20(cometRewards().rewardConfig(address(cToken())).token);
    uint256 rewardAmount = toWithdraw[1];
    if (rewardAmount > 0) {
      uint256 rewardBalance = rewardToken.balanceOf(address(this));
      if (rewardBalance < rewardAmount) {
        // Claim all rewards
        address[] memory holders = new address[](1);
        holders[0] = address(this);
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken();
        cometRewards().claimTo(address(cToken()), address(this), address(this), true);
      }
      rewardToken.safeTransfer(recipient, rewardAmount);
    }

    return _connector_supportedWithdrawals();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_specialWithdraw(
    uint256,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata,
    address recipient
  )
    internal
    virtual
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    ICERC20 cToken_ = cToken();
    balanceChanges = new uint256[](2);

    actualWithdrawnTokens = new address[](1);
    actualWithdrawnAmounts = new uint256[](1);
    result = "";
    if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT) {
      uint256 shares = toWithdraw[0];
      uint256 balanceBefore = underlyingBalance();
      IERC20(cToken_).safeTransfer(recipient, shares);
      uint256 balanceAfter = underlyingBalance();
      balanceChanges[0] = balanceBefore - balanceAfter;
      actualWithdrawnTokens[0] = address(cToken_);
      actualWithdrawnAmounts[0] = shares;
    } else if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT) {
      // Note: we round down because if we were to round up, we might end up withdrawing more than the position's
      // balance, which would end up reverting on the vault
      uint256 shares = convertToShares(toWithdraw[0]);
      uint256 balanceBefore = underlyingBalance();
      IERC20(cToken_).safeTransfer(recipient, shares);
      uint256 balanceAfter = underlyingBalance();
      balanceChanges[0] = balanceBefore - balanceAfter;
      actualWithdrawnTokens[0] = address(cToken_);
      actualWithdrawnAmounts[0] = shares;
    } else {
      revert InvalidSpecialWithdrawalCode(withdrawalCode);
    }
  }

  // revisar
  // slither-disable-next-line naming-convention,dead-code
  function _connector_migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata
  )
    internal
    virtual
    override
    returns (bytes memory)
  {
    // Transfer cToken
    ICERC20 cToken_ = cToken();
    uint256 cTokenBalance = cToken_.balanceOf(address(this));
    IERC20(cToken_).safeTransfer(address(newStrategy), cTokenBalance);

    // Claim and transfer comp
    IERC20 rewardToken = IERC20(cometRewards().rewardConfig(address(cToken())).token);
    cometRewards().claimTo(address(cToken()), address(this), address(this), true);
    uint256 rewardBalance = rewardToken.balanceOf(address(this));
    rewardToken.safeTransfer(address(newStrategy), rewardBalance);

    return abi.encode(cTokenBalance, rewardBalance);
  }

  // solhint-disable no-empty-blocks
  // slither-disable-next-line naming-convention,dead-code
  function _connector_strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationData
  )
    internal
    virtual
    override
  { }

  /**
   * @notice Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
   * scenario where all the conditions are met.
   * @dev Treats shares as principal and computes for assets by taking into account interest accrual. Relies on latest
   * `baseSupplyIndex` from Comet which is the global index used for interest accrual the from supply rate.
   * @param shares The amount of shares to be converted to assets
   * @return The total amount of assets computed from the given shares
   */
  function convertToAssets(uint256 shares) public view returns (uint256) {
    uint64 baseSupplyIndex_ = accruedSupplyIndex();
    return shares > 0 ? presentValueSupply(baseSupplyIndex_, shares, Rounding.DOWN) : 0;
  }

  /**
   * @notice Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
   * scenario where all the conditions are met.
   * @dev Assets are converted to shares by computing for the principal using the latest `baseSupplyIndex` from Comet.
   * @param assets The amount of assets to be converted to shares
   * @return The total amount of shares computed from the given assets
   */
  function convertToShares(uint256 assets) public view returns (uint256) {
    uint64 baseSupplyIndex_ = accruedSupplyIndex();
    return assets > 0 ? principalValueSupply(baseSupplyIndex_, assets, Rounding.DOWN) : 0;
  }

  /**
   * @notice Total assets of an account that are managed by this vault
   * @dev The asset balance is computed from an account's shares balance which mirrors how Comet
   * computes token balances. This is done this way since balances are ever-increasing due to
   * interest accrual.
   * @return The total amount of assets held by an account
   */
  function underlyingBalance() public view returns (uint256) {
    uint64 baseSupplyIndex_ = accruedSupplyIndex();
    uint256 principal = cToken().balanceOf(address(this));
    return principal > 0 ? presentValueSupply(baseSupplyIndex_, principal, Rounding.DOWN) : 0;
  }

  /**
   * @dev This returns latest baseSupplyIndex regardless of whether comet.accrueAccount has been called for the
   * current block. This works like `Comet.accruedInterestedIndices` at but not including computation of
   * `baseBorrowIndex` since we do not need that index in CometWrapper:
   * https://github.com/compound-finance/comet/blob/63e98e5d231ef50c755a9489eb346a561fc7663c/contracts/Comet.sol#L383-L394
   */
  function accruedSupplyIndex() internal view returns (uint64) {
    (uint64 baseSupplyIndex_,, uint40 lastAccrualTime) = getSupplyIndices();
    uint256 timeElapsed = uint256(getNowInternal() - lastAccrualTime);
    if (timeElapsed > 0) {
      uint256 utilization = cToken().getUtilization();
      uint256 supplyRate = cToken().getSupplyRate(utilization);
      baseSupplyIndex_ += safe64(mulFactor(baseSupplyIndex_, supplyRate * timeElapsed));
    }
    return baseSupplyIndex_;
  }

  /**
   * @dev To maintain accuracy, we fetch `baseSupplyIndex` and `trackingSupplyIndex` directly from Comet.
   * baseSupplyIndex is used on the principal to get the user's latest balance including interest accruals.
   * trackingSupplyIndex is used to compute for rewards accruals.
   */
  function getSupplyIndices()
    internal
    view
    returns (uint64 baseSupplyIndex_, uint64 trackingSupplyIndex_, uint40 lastAccrualTime_)
  {
    TotalsBasic memory totals = CometExt(address(cToken())).totalsBasic();
    baseSupplyIndex_ = totals.baseSupplyIndex;
    trackingSupplyIndex_ = totals.trackingSupplyIndex;
    lastAccrualTime_ = totals.lastAccrualTime;
  }

  /**
   * @dev The current timestamp
   * From https://github.com/compound-finance/comet/blob/main/contracts/Comet.sol#L375-L378
   */
  function getNowInternal() internal view returns (uint40) {
    return uint40(block.timestamp);
  }
}
