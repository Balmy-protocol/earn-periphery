// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
  StrategyId,
  IEarnStrategy,
  SpecialWithdrawalCode,
  IDelayedWithdrawalAdapter
} from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";
import { BaseConnector } from "./base/BaseConnector.sol";

abstract contract ERC4626Connector is BaseConnector {
  using SafeERC20 for IERC20;
  using SafeERC20 for IERC4626;

  /// @notice Returns the address of the ERC4626 vault
  // slither-disable-next-line naming-convention
  IERC4626 public immutable ERC4626Vault;
  address internal immutable _assetToken;

  constructor(IERC4626 vault) {
    ERC4626Vault = vault;
    _assetToken = vault.asset();
    maxApproveVault();
  }

  /// @notice Performs a max approve to the vault, so that we can deposit without any worries
  function maxApproveVault() public {
    IERC20(_connector_asset()).forceApprove(address(ERC4626Vault), type(uint256).max);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_asset() internal view override returns (address) {
    return _assetToken;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_allTokens() internal view override returns (address[] memory tokens) {
    tokens = new address[](1);
    tokens[0] = _connector_asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedWithdrawals()
    internal
    view
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return new IEarnStrategy.WithdrawalType[](1);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isDepositTokenSupported(address depositToken) internal view virtual override returns (bool) {
    return depositToken == _connector_asset() || depositToken == address(ERC4626Vault);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal view virtual override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(ERC4626Vault);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxDeposit(address depositToken) internal view virtual override returns (uint256) {
    if (depositToken == _connector_asset()) {
      return ERC4626Vault.maxDeposit(address(this));
    } else if (depositToken == address(ERC4626Vault)) {
      return type(uint256).max;
    } else {
      revert InvalidDepositToken(depositToken);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_totalBalances()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    tokens = new address[](1);
    tokens[0] = _connector_asset();
    balances = new uint256[](1);
    balances[0] = ERC4626Vault.previewRedeem(ERC4626Vault.balanceOf(address(this)));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isSpecialWithdrawalSupported(
    SpecialWithdrawalCode withdrawalCode
  )
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

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxWithdraw()
    internal
    view
    virtual
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    tokens = new address[](1);
    tokens[0] = _connector_asset();
    withdrawable = new uint256[](1);
    withdrawable[0] = ERC4626Vault.maxWithdraw(address(this));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_delayedWithdrawalAdapter(
    address token
  )
    internal
    view
    virtual
    override
    returns (IDelayedWithdrawalAdapter)
  // solhint-disable-next-line no-empty-blocks
  { }

  // slither-disable-next-line naming-convention,dead-code
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
      uint256 shares = ERC4626Vault.deposit(depositAmount, address(this));
      // Note: there might be slippage or a deposit fee, so we will re-calculate the amount of assets deposited
      //       based on the amount of shares minted
      return ERC4626Vault.previewRedeem(shares);
    } else if (depositToken == address(ERC4626Vault)) {
      return ERC4626Vault.previewRedeem(depositAmount);
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
    // Note: we assume params are consistent and valid because they were validated by the EarnVault
    // slither-disable-next-line unused-return
    ERC4626Vault.withdraw(toWithdraw[0], recipient, address(this));
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
    virtual
    override
    returns (uint256[] memory withdrawn, IEarnStrategy.WithdrawalType[] memory withdrawalTypes, bytes memory result)
  {
    withdrawn = new uint256[](1);
    withdrawalTypes = new IEarnStrategy.WithdrawalType[](1);

    if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT) {
      uint256 shares = abi.decode(withdrawData, (uint256));
      uint256 assets = ERC4626Vault.previewRedeem(shares);
      ERC4626Vault.safeTransfer(recipient, shares);
      withdrawn[0] = assets;
      result = abi.encode(assets);
    } else if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT) {
      uint256 assets = abi.decode(withdrawData, (uint256));
      uint256 shares = ERC4626Vault.previewWithdraw(assets);
      ERC4626Vault.safeTransfer(recipient, shares);
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
    virtual
    override
    returns (bytes memory)
  {
    uint256 balance = ERC4626Vault.balanceOf(address(this));
    ERC4626Vault.safeTransfer(address(newStrategy), balance);
    return abi.encode(balance);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationData
  )
    internal
    virtual
    override
  // solhint-disable-next-line no-empty-blocks
  { }
}
