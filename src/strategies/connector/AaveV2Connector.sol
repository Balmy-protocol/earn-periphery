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

interface IAaveV2Pool {
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

contract AaveV2Connector is BaseConnector {
  using SafeERC20 for IERC20;
  using Math for uint256;

  IERC20 internal immutable _vault;
  IERC20 internal immutable _asset;
  IAaveV2Pool internal immutable _pool;

  constructor(IERC20 vault, IERC20 asset, IAaveV2Pool pool) {
    _vault = vault;
    _asset = asset;
    _pool = pool;
    maxApproveVault();
  }

  /// @notice Performs a max approve to the vault, so that we can deposit without any worries
  function maxApproveVault() public {
    _asset.forceApprove(address(_vault), type(uint256).max);
    _asset.forceApprove(address(_pool), type(uint256).max);
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
      _pool.deposit(depositToken, depositAmount, address(this), 0);
      uint256 sharesDeposited = _vault.balanceOf(address(this)) - balance;
      return sharesDeposited;
    } else if (depositToken == address(_vault)) {
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
    _pool.withdraw(address(_asset), assets, recipient);
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
    if (
      withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT
        || withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT
    ) {
      uint256 assets = abi.decode(withdrawData, (uint256));
      IERC20(_vault).safeTransfer(recipient, assets);
      withdrawn[0] = assets;
      result = abi.encode(assets);
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
    return (_vault.balanceOf(account));
  }

  // slither-disable-next-line dead-code
  function _convertSharesToAssets(uint256 shares) private view returns (uint256) {
    if (_vault.totalSupply() == 0) {
      return shares;
    }
    return shares.mulDiv(_vault.balanceOf(address(this)), _vault.totalSupply(), Math.Rounding.Floor);
  }

  // slither-disable-next-line dead-code
  function _convertAssetsToShares(uint256 assets) private view returns (uint256) {
    if (_vault.totalSupply() == 0) {
      return assets;
    }
    return assets.mulDiv(_vault.totalSupply(), _vault.balanceOf(address(this)), Math.Rounding.Ceil);
  }
}
