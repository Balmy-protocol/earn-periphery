// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { StrategyId, IEarnStrategy, SpecialWithdrawalCode } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IDelayedWithdrawalAdapter } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";

import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";
import { BaseConnector } from "./base/BaseConnector.sol";

abstract contract ERC4626Connector is BaseConnector, Initializable {
  using SafeERC20 for IERC20;
  using SafeERC20 for IERC4626;
  using Math for uint256;

  /// @notice Returns the address of the ERC4626 vault
  // slither-disable-next-line naming-convention
  function ERC4626Vault() public view virtual returns (IERC4626);
  function _asset() internal view virtual returns (IERC20);

  /// @notice Performs a max approve to the vault, so that we can deposit without any worries
  function maxApproveVault() public {
    _asset().forceApprove(address(ERC4626Vault()), type(uint256).max);
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
    return depositToken == _connector_asset() || depositToken == address(ERC4626Vault());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal view virtual override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(ERC4626Vault());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxDeposit(address depositToken) internal view virtual override returns (uint256) {
    IERC4626 vault = ERC4626Vault();
    if (depositToken == _connector_asset()) {
      return vault.maxDeposit(address(this));
    } else if (depositToken == address(vault)) {
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
    IERC4626 vault = ERC4626Vault();
    tokens = new address[](1);
    tokens[0] = _connector_asset();
    balances = new uint256[](1);
    balances[0] = vault.previewRedeem(vault.balanceOf(address(this)));
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
    withdrawable[0] = ERC4626Vault().maxWithdraw(address(this));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_delayedWithdrawalAdapter(address token)
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
    IERC4626 vault = ERC4626Vault();
    if (depositToken == _connector_asset()) {
      uint256 shares = vault.deposit(depositAmount, address(this));
      // Note: there might be slippage or a deposit fee, so we will re-calculate the amount of assets deposited
      //       based on the amount of shares minted
      return vault.previewRedeem(shares);
    } else if (depositToken == address(vault)) {
      return vault.previewRedeem(depositAmount);
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
    ERC4626Vault().withdraw(toWithdraw[0], recipient, address(this));
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
    IERC4626 vault = ERC4626Vault();
    balanceChanges = new uint256[](1);
    actualWithdrawnTokens = new address[](1);
    actualWithdrawnAmounts = new uint256[](1);
    result = "";

    if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT) {
      uint256 shares = toWithdraw[0];
      uint256 assets = vault.previewRedeem(shares);
      vault.safeTransfer(recipient, shares);
      balanceChanges[0] = assets;
      actualWithdrawnTokens[0] = address(vault);
      actualWithdrawnAmounts[0] = shares;
    } else if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT) {
      uint256 assets = toWithdraw[0];
      uint256 shares = vault.previewWithdraw(assets);
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
    virtual
    override
    returns (bytes memory)
  {
    IERC4626 vault = ERC4626Vault();
    uint256 balance = vault.balanceOf(address(this));
    vault.safeTransfer(address(newStrategy), balance);
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
