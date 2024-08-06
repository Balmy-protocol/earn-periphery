// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import {
  BaseConnector,
  IEarnStrategy,
  SpecialWithdrawalCode,
  IDelayedWithdrawalAdapter,
  StrategyId
} from "./base/BaseConnector.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";

interface IVault is IERC20 {
  function deposit(uint256) external;
  function withdraw(uint256) external;
  function withdrawAll() external;
  function balance() external view returns (uint256);
  function want() external view returns (IERC20);
}

contract BeefyConnector is BaseConnector {
  using SafeERC20 for IERC20;
  using Math for uint256;

  IVault internal immutable _vault;
  IERC20 internal immutable _asset;

  constructor(IVault vault) {
    _vault = vault;
    _asset = IERC20(_vault.want());
    maxApproveVault();
  }

  /// @notice Performs a max approve to the vault, so that we can deposit without any worries
  function maxApproveVault() public {
    _asset.forceApprove(address(_vault), type(uint256).max);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_asset() internal view override returns (address) {
    return address(_asset);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_allTokens() internal view override returns (address[] memory tokens) {
    tokens = new address[](1);
    tokens[0] = _connector_asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isDepositTokenSupported(address depositToken) internal view override returns (bool) {
    return depositToken == _connector_asset() || depositToken == address(_vault);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal view override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(_vault);
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
    balances[0] = _vaultBalanceInAssets(address(this));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_delayedWithdrawalAdapter(address) internal pure override returns (IDelayedWithdrawalAdapter) {
    return IDelayedWithdrawalAdapter(address(0));
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
      uint256 balance = _vault.balanceOf(address(this));
      _vault.deposit(depositAmount);
      uint256 sharesDeposited = _vault.balanceOf(address(this)) - balance;
      return _convertSharesToAssets(sharesDeposited);
    } else if (depositToken == address(_vault)) {
      return _convertSharesToAssets(depositAmount);
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

    // We convert the assets to shares with rounding up
    // This way we make sure that the correct amount is withdrawn
    uint256 shares = _convertAssetsToShares(assets);
    _vault.withdraw(shares);

    uint256 balance = _asset.balanceOf(address(this));
    // If we have less assets than requested, we transfer the maximum
    if (assets > balance) {
      assets = balance;
    }

    _asset.safeTransfer(recipient, assets);

    return _connector_supportedWithdrawals();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_specialWithdraw(
    uint256,
    SpecialWithdrawalCode withdrawalCode,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    override
    returns (uint256[] memory withdrawn, IEarnStrategy.WithdrawalType[] memory withdrawalTypes, bytes memory result)
  {
    withdrawn = new uint256[](1);
    withdrawalTypes = new IEarnStrategy.WithdrawalType[](1);
    if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT) {
      uint256 shares = abi.decode(withdrawData, (uint256));
      uint256 assets = _convertSharesToAssets(shares);
      IERC20(_vault).safeTransfer(recipient, shares);
      withdrawn[0] = assets;
      result = abi.encode(assets);
    } else if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT) {
      uint256 assets = abi.decode(withdrawData, (uint256));
      uint256 shares = _convertAssetsToShares(assets);
      IERC20(_vault).safeTransfer(recipient, shares);
      withdrawn[0] = assets;
      result = abi.encode(shares);
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
    uint256 balance = _vault.balanceOf(address(this));
    IERC20(_vault).safeTransfer(address(newStrategy), balance);
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

  // slither-disable-next-line dead-code
  function _vaultBalanceInAssets(address account) private view returns (uint256) {
    return _convertSharesToAssets(_vault.balanceOf(account));
  }

  // slither-disable-next-line dead-code
  function _convertSharesToAssets(uint256 shares) private view returns (uint256) {
    if (_vault.totalSupply() == 0) {
      return shares;
    }
    return shares.mulDiv(_vault.balance(), _vault.totalSupply(), Math.Rounding.Floor);
  }

  // slither-disable-next-line dead-code
  function _convertAssetsToShares(uint256 assets) private view returns (uint256) {
    if (_vault.totalSupply() == 0) {
      return assets;
    }
    return assets.mulDiv(_vault.totalSupply(), _vault.balance(), Math.Rounding.Ceil);
  }
}
