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

interface IAToken is IERC20 {
  function scaledTotalSupply() external view returns (uint256);
  // slither-disable-next-line naming-convention
  function UNDERLYING_ASSET_ADDRESS() external returns (address);
}

interface IAaveV2Pool {
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

abstract contract AaveV2Connector is BaseConnector, Initializable {
  using SafeERC20 for IERC20;
  using Math for uint256;

  /// @notice Returns the pool's address
  function pool() public view virtual returns (IAaveV2Pool);
  /// @notice Returns the aToken's address
  function aToken() public view virtual returns (IAToken);
  function _asset() internal view virtual returns (IERC20);

  /// @notice Performs a max approve to the pool, so that we can deposit without any worries
  function maxApprovePool() public {
    _asset().forceApprove(address(pool()), type(uint256).max);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_init() internal onlyInitializing {
    maxApprovePool();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_asset() internal view override returns (address) {
    return address(_asset());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_allTokens() internal view override returns (address[] memory tokens) {
    tokens = new address[](1);
    tokens[0] = _connector_asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isDepositTokenSupported(address depositToken) internal view override returns (bool) {
    return depositToken == _connector_asset() || depositToken == address(aToken());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal view override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(aToken());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxDeposit(address depositToken) internal view override returns (uint256) {
    if (!_connector_isDepositTokenSupported(depositToken)) {
      revert InvalidDepositToken(depositToken);
    }
    return type(uint256).max;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedWithdrawals() internal pure override returns (IEarnStrategy.WithdrawalType[] memory) {
    return new IEarnStrategy.WithdrawalType[](1); // IMMEDIATE
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isSpecialWithdrawalSupported(SpecialWithdrawalCode withdrawalCode)
    internal
    pure
    override
    returns (bool)
  {
    return withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT
      || withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedSpecialWithdrawals()
    internal
    pure
    override
    returns (SpecialWithdrawalCode[] memory codes)
  {
    codes = new SpecialWithdrawalCode[](2);
    codes[0] = SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT;
    codes[1] = SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxWithdraw()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    (tokens, withdrawable) = _connector_totalBalances();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    tokens = new address[](1);
    balances = new uint256[](1);
    tokens[0] = _connector_asset();
    balances[0] = aToken().balanceOf(address(this));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_delayedWithdrawalAdapter(address) internal pure override returns (IDelayedWithdrawalAdapter) {
    return IDelayedWithdrawalAdapter(address(0));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_assetYieldCoefficient() internal view override returns (uint256) {
    IAToken vault_ = aToken();
    uint256 shares = vault_.scaledTotalSupply();
    if (shares == 0) {
      return 1e18;
    }
    uint256 assets = vault_.totalSupply();
    return assets.mulDiv(1e18, shares, Math.Rounding.Floor);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_rewardEmissionsPerSecondPerAsset()
    internal
    pure
    override
    returns (uint256[] memory, uint256[] memory)
  {
    return (new uint256[](0), new uint256[](0));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_totalAssetsInFarm() internal view override returns (uint256) {
    return aToken().totalSupply();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  {
    if (depositToken == _connector_asset()) {
      pool().deposit(depositToken, depositAmount, address(this), 0);
      return depositAmount;
    } else if (depositToken == address(aToken())) {
      return depositAmount;
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
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    uint256 assets = toWithdraw[0];
    // slither-disable-next-line unused-return
    pool().withdraw(address(_asset()), assets, recipient);
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
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    if (
      withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT
        || withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT
    ) {
      IERC20 aaveVault = aToken();
      balanceChanges = new uint256[](1);
      actualWithdrawnTokens = new address[](1);
      actualWithdrawnAmounts = new uint256[](1);
      result = "";
      uint256 assets = toWithdraw[0];
      aaveVault.safeTransfer(recipient, assets);
      balanceChanges[0] = assets;
      actualWithdrawnTokens[0] = address(aaveVault);
      actualWithdrawnAmounts[0] = assets;
    } else {
      revert InvalidSpecialWithdrawalCode(withdrawalCode);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata
  )
    internal
    override
    returns (bytes memory)
  {
    IERC20 vault_ = aToken();
    uint256 balance = vault_.balanceOf(address(this));
    vault_.safeTransfer(address(newStrategy), balance);
    return abi.encode(balance);
  }

  // solhint-disable no-empty-blocks
  // slither-disable-next-line naming-convention,dead-code
  function _connector_strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationData
  )
    internal
    override
  { }
}
