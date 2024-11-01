// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  BaseConnector,
  IEarnStrategy,
  SpecialWithdrawalCode,
  IDelayedWithdrawalAdapter,
  StrategyId
} from "./base/BaseConnector.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";

interface ICERC20 is IERC20 {
  function mint(uint256 underlyingAmount) external returns (uint256);
  function redeemUnderlying(uint256 underlyingAmount) external returns (uint256);
  function redeem(uint256 shares) external returns (uint256);
  function balanceOfUnderlying(address) external returns (uint256);
  function exchangeRateStored() external view returns (uint256);
  function decimals() external view returns (uint256);
  function totalReserves() external view returns (uint256);
}

interface IComptroller {
  function claimComp(address[] memory holders, ICERC20[] memory cTokens, bool borrowers, bool suppliers) external;
  function compSpeeds(address cToken) external view returns (uint256);
  function compAccrued(address) external view returns (uint256);
}

abstract contract CompoundV2Connector is BaseConnector, Initializable {
  using SafeERC20 for IERC20;
  using Math for uint256;

  error InvalidWithdrawal(uint256 errorCode);

  /// @notice Returns the comp token address
  function comp() public view virtual returns (IERC20);
  /// @notice Returns the cToken's address
  function cToken() public view virtual returns (ICERC20);
  /// @notice Returns the comptroller, the rewards controller
  function comptroller() public view virtual returns (IComptroller);
  function _asset() internal view virtual returns (IERC20);

  /// @notice Performs a max approve to the pool, so that we can deposit without any worries
  function maxApproveCToken() public {
    _asset().forceApprove(address(cToken()), type(uint256).max);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_init() internal onlyInitializing {
    maxApproveCToken();
  }

  function _connector_asset() internal view virtual override returns (address) {
    return address(_asset());
  }

  function _connector_allTokens() internal view virtual override returns (address[] memory tokens) {
    tokens = new address[](2);
    tokens[0] = _connector_asset();
    tokens[1] = address(comp());
  }

  function _connector_isDepositTokenSupported(address depositToken) internal view virtual override returns (bool) {
    return depositToken == _connector_asset() || depositToken == address(cToken());
  }

  function _connector_supportedDepositTokens() internal view virtual override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(cToken());
  }

  function _connector_maxDeposit(address depositToken) internal view virtual override returns (uint256) {
    if (!_connector_isDepositTokenSupported(depositToken)) {
      revert InvalidDepositToken(depositToken);
    }
    return type(uint256).max;
  }

  function _connector_supportedWithdrawals()
    internal
    view
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return new IEarnStrategy.WithdrawalType[](_connector_allTokens().length); // IMMEDIATE
  }

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

  function _connector_maxWithdraw()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    (tokens, withdrawable) = _connector_totalBalances();
  }

  function _connector_totalBalances()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    tokens = _connector_allTokens();
    balances = new uint256[](tokens.length);
    balances[0] = _convertSharesToAssets(cToken().balanceOf(address(this)));
    balances[1] = comp().balanceOf(address(this)) + comptroller().compAccrued(address(this));
  }

  function _connector_delayedWithdrawalAdapter(address)
    internal
    view
    virtual
    override
    returns (IDelayedWithdrawalAdapter)
  {
    return IDelayedWithdrawalAdapter(address(0));
  }

  function _connector_assetYieldCoefficient()
    internal
    view
    virtual
    override
    returns (uint256 coefficient, uint256 multiplier)
  {
    multiplier = 1e18;
    ICERC20 cToken_ = cToken();
    uint256 shares = cToken_.totalSupply();
    if (shares == 0) {
      return (multiplier, multiplier);
    }
    uint256 assets = cToken_.totalReserves();
    coefficient = assets.mulDiv(multiplier, shares, Math.Rounding.Floor);
  }

  function _connector_rewardEmissionsPerSecondPerAsset()
    internal
    view
    virtual
    override
    returns (uint256[] memory emissions, uint256[] memory multipliers)
  {
    ICERC20 cToken_ = cToken();
    uint256 totalAssets = Math.max(cToken_.totalSupply(), 1);
    emissions = new uint256[](1);
    multipliers = new uint256[](1);
    uint256 emissionPerSecond = comptroller().compSpeeds(address(cToken_));
    multipliers[0] = 1e30;
    emissions[0] = emissionPerSecond.mulDiv(1e30, totalAssets, Math.Rounding.Floor);
  }

  function _connector_totalAssetsInFarm() internal view virtual override returns (uint256) {
    return cToken().totalSupply();
  }

  function _connector_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    virtual
    override
    returns (uint256 assetsDeposited)
  {
    if (depositToken == _connector_asset()) {
      uint256 balance = cToken().balanceOf(address(this));
      cToken().mint(depositAmount);
      return _convertSharesToAssets(cToken().balanceOf(address(this)) - balance);
    } else if (depositToken == address(cToken())) {
      return _convertSharesToAssets(depositAmount);
    } else {
      revert InvalidDepositToken(depositToken);
    }
  }

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
    uint256 assets = toWithdraw[0];
    if (assets > 0) {
      IERC20 asset = _asset();
      uint256 errorCode = cToken().redeem(_convertAssetsToShares(assets));
      if (errorCode != 0) {
        revert InvalidWithdrawal(errorCode);
      }

      uint256 balance = asset.balanceOf(address(this));
      // If we have less assets than requested, we transfer the maximum
      if (assets > balance) {
        assets = balance;
      }
      asset.safeTransfer(recipient, assets);
    }

    if (toWithdraw[1] > 0) {
      uint256 rewardBalance = comp().balanceOf(address(this));
      if (rewardBalance < toWithdraw[1]) {
        // Claim all rewards
        address[] memory holders = new address[](1);
        holders[0] = address(this);
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken();
        comptroller().claimComp(holders, cTokens, false, true);
        rewardBalance = comp().balanceOf(address(this));
      }
      comp().safeTransfer(recipient, toWithdraw[1]);
    }

    return _connector_supportedWithdrawals();
  }

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
    address cToken_ = address(cToken());
    balanceChanges = new uint256[](_connector_allTokens().length);

    actualWithdrawnTokens = new address[](1);
    actualWithdrawnAmounts = new uint256[](1);
    result = "";
    if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT) {
      uint256 shares = toWithdraw[0];
      uint256 assets = _convertSharesToAssets(shares);
      IERC20(cToken_).safeTransfer(recipient, shares);
      balanceChanges[0] = assets;
      actualWithdrawnTokens[0] = cToken_;
      actualWithdrawnAmounts[0] = shares;
    } else if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT) {
      uint256 assets = toWithdraw[0];
      uint256 shares = _convertAssetsToShares(assets);
      IERC20(cToken_).safeTransfer(recipient, shares);
      balanceChanges[0] = assets;
      actualWithdrawnTokens[0] = cToken_;
      actualWithdrawnAmounts[0] = shares;
    } else {
      revert InvalidSpecialWithdrawalCode(withdrawalCode);
    }
  }

  function _connector_migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata
  )
    internal
    virtual
    override
    returns (bytes memory)
  {
    uint256 balance = cToken().balanceOf(address(this));
    IERC20(cToken()).safeTransfer(address(newStrategy), balance);
    return abi.encode(balance);
  }

  function _connector_strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationData
  )
    internal
    virtual
    override
  { }

  // slither-disable-next-line dead-code
  function _convertSharesToAssets(uint256 shares) private view returns (uint256) {
    uint256 underlyingTokenDecimals =
      Token.NATIVE_TOKEN == address(_asset()) ? 18 : ICERC20(address(_asset())).decimals();
    uint256 magnitude = (10 + underlyingTokenDecimals);
    return shares.mulDiv(cToken().exchangeRateStored(), 10 ** magnitude, Math.Rounding.Ceil);
  }

  // slither-disable-next-line dead-code
  function _convertAssetsToShares(uint256 assets) private view returns (uint256) {
    uint256 underlyingTokenDecimals =
      Token.NATIVE_TOKEN == address(_asset()) ? 18 : ICERC20(address(_asset())).decimals();
    uint256 magnitude = (10 + underlyingTokenDecimals);
    return assets.mulDiv(10 ** magnitude, cToken().exchangeRateStored(), Math.Rounding.Floor);
  }
}
