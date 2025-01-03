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

interface IBeefyVault is IERC20 {
  function deposit(uint256) external;
  function withdraw(uint256) external;
  function withdrawAll() external;
  function balance() external view returns (uint256);
  function want() external view returns (IERC20);
}

// The BeefyConnector is an implementation based on Beefy's Adapter to interact directly with Beefy's Vaults
// https://docs.beefy.finance/developer-documentation/other-beefy-contracts/beefywrapper-contract
abstract contract BeefyConnector is BaseConnector, Initializable {
  using SafeERC20 for IERC20;
  using SafeERC20 for IBeefyVault;
  using Math for uint256;

  /// @notice Returns the address of the Beefy vault
  function beefyVault() public view virtual returns (IBeefyVault);
  function _asset() internal view virtual returns (IERC20);

  /// @notice Performs a max approve to the vault, so that we can deposit without any worries
  function maxApproveVault() public {
    _asset().forceApprove(address(beefyVault()), type(uint256).max);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_init() internal onlyInitializing {
    maxApproveVault();
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
    return depositToken == _connector_asset() || depositToken == address(beefyVault());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal view override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(beefyVault());
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
    IBeefyVault vault = beefyVault();
    tokens = new address[](1);
    balances = new uint256[](1);
    tokens[0] = _connector_asset();
    balances[0] = _convertSharesToAssets(vault, vault.balanceOf(address(this)));
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
    IBeefyVault vault = beefyVault();
    if (depositToken == _connector_asset()) {
      IERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);
      uint256 balance = vault.balanceOf(address(this));
      vault.deposit(depositAmount);
      uint256 sharesDeposited = vault.balanceOf(address(this)) - balance;
      return _convertSharesToAssets(vault, sharesDeposited);
    } else if (depositToken == address(vault)) {
      IERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);
      return _convertSharesToAssets(vault, depositAmount);
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
    IBeefyVault vault = beefyVault();
    IERC20 asset = _asset();

    // We convert the assets to shares with rounding up
    // This way we make sure that the correct amount is withdrawn
    uint256 shares = _convertAssetsToShares(vault, assets);
    vault.withdraw(shares);

    uint256 balance = asset.balanceOf(address(this));
    // If we have less assets than requested, we transfer the maximum
    if (assets > balance) {
      assets = balance;
    }

    asset.safeTransfer(recipient, assets);

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
    IBeefyVault vault = beefyVault();
    balanceChanges = new uint256[](1);
    actualWithdrawnTokens = new address[](1);
    actualWithdrawnAmounts = new uint256[](1);
    result = "";
    if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT) {
      uint256 shares = toWithdraw[0];
      uint256 assets = _convertSharesToAssets(vault, shares);
      vault.safeTransfer(recipient, shares);
      balanceChanges[0] = assets;
      actualWithdrawnTokens[0] = address(vault);
      actualWithdrawnAmounts[0] = shares;
    } else if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT) {
      uint256 assets = toWithdraw[0];
      uint256 shares = _convertAssetsToShares(vault, assets);
      vault.safeTransfer(recipient, shares);
      balanceChanges[0] = assets;
      actualWithdrawnTokens[0] = address(vault);
      actualWithdrawnAmounts[0] = shares;
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
    IBeefyVault vault = beefyVault();
    uint256 balance = vault.balanceOf(address(this));
    vault.safeTransfer(address(newStrategy), balance);
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
  function _convertSharesToAssets(IBeefyVault vault, uint256 shares) private view returns (uint256) {
    uint256 totalSupply = vault.totalSupply();
    if (totalSupply == 0) {
      return shares;
    }
    return shares.mulDiv(vault.balance(), totalSupply, Math.Rounding.Floor);
  }

  // slither-disable-next-line dead-code
  function _convertAssetsToShares(IBeefyVault vault, uint256 assets) private view returns (uint256) {
    uint256 totalSupply = vault.totalSupply();
    if (totalSupply == 0) {
      return assets;
    }
    return assets.mulDiv(totalSupply, vault.balance(), Math.Rounding.Floor);
  }
}
