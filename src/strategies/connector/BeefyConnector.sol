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
import { IVault } from "@beefy-contracts/interfaces/beefy/IVault.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract BeefyConnector is BaseConnector {
  using SafeERC20 for IERC20;
  using Math for uint256;

  IVault internal immutable vault;
  IERC20 internal immutable asset;

  constructor(IVault _vault) {
    vault = _vault;
    asset = IERC20(_vault.want());
    maxApproveVault();
  }

  /// @notice Performs a max approve to the vault, so that we can deposit without any worries
  function maxApproveVault() public {
    asset.forceApprove(address(vault), type(uint256).max);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_asset() internal view override returns (address) {
    return address(asset);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_allTokens() internal view override returns (address[] memory tokens) {
    tokens = new address[](1);
    tokens[0] = _connector_asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isDepositTokenSupported(address depositToken) internal view override returns (bool) {
    return depositToken == _connector_asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal view override returns (address[] memory supported) {
    supported = new address[](1);
    supported[0] = _connector_asset();
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
  function _connector_isSpecialWithdrawalSupported(SpecialWithdrawalCode) internal pure override returns (bool) {
    return false;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedSpecialWithdrawals()
    internal
    pure
    override
    returns (SpecialWithdrawalCode[] memory codes)
  {
    return new SpecialWithdrawalCode[](0);
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
    balances[0] = vaultBalanceInAssets(address(this));
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
    if (!_connector_isDepositTokenSupported(depositToken)) {
      revert InvalidDepositToken(depositToken);
    }

    uint256 balance = vault.balanceOf(address(this));
    vault.deposit(depositAmount);
    uint256 sharesDeposited = vault.balanceOf(address(this)) - balance;
    return convertSharesToAssets(sharesDeposited);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_withdraw(
    uint256,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    if (tokens.length != 1 || !_connector_isDepositTokenSupported(tokens[0])) {
      revert InvalidDepositToken(tokens[0]);
    }

    uint256 assets = toWithdraw[0];
    uint256 shares = convertAssetsToShares(assets);
    uint256 balanceBefore = asset.balanceOf(address(this));
    vault.withdraw(shares);
    asset.safeTransfer(recipient, asset.balanceOf(address(this)) - balanceBefore);
    return _connector_supportedWithdrawals();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_specialWithdraw(
    uint256,
    SpecialWithdrawalCode withdrawalCode,
    bytes calldata,
    address
  )
    internal
    pure
    override
    returns (uint256[] memory, IEarnStrategy.WithdrawalType[] memory, bytes memory)
  {
    revert InvalidSpecialWithdrawalCode(withdrawalCode);
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
    uint256 balanceBefore = asset.balanceOf(address(this));
    vault.withdrawAll();
    uint256 withdrawn = asset.balanceOf(address(this)) - balanceBefore;
    asset.safeTransfer(address(newStrategy), withdrawn);
    return abi.encode(withdrawn);
  }

  // solhint-disable-next-line no-empty-blocks
  // slither-disable-next-line naming-convention,dead-code
  function _connector_strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationData
  )
    internal
    override
  { }

  // slither-disable-next-line naming-convention,dead-code
  function vaultBalanceInAssets(address account) internal view returns (uint256) {
    return convertSharesToAssets(vault.balanceOf(account));
  }

  // slither-disable-next-line naming-convention,dead-code
  function convertSharesToAssets(uint256 shares) private view returns (uint256) {
    return shares.mulDiv(vault.balance(), vault.totalSupply(), Math.Rounding.Floor);
  }

  // slither-disable-next-line naming-convention,dead-code
  function convertAssetsToShares(uint256 assets) private view returns (uint256) {
    if (vault.totalSupply() == 0) {
      return assets;
    }
    return assets.mulDiv(vault.totalSupply(), vault.balance(), Math.Rounding.Floor);
  }
}
