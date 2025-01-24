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
import { LibCompound } from "./LibCompound.sol";

interface IComptroller {
  function claimComp(address[] memory holders, ICERC20[] memory cTokens, bool borrowers, bool suppliers) external;
  function compSpeeds(address cToken) external view returns (uint256);
  function compAccrued(address) external view returns (uint256);
  function mintGuardianPaused(ICERC20 cToken) external view returns (bool);
}

abstract contract CompoundV2Connector is BaseConnector, Initializable {
  using SafeERC20 for IERC20;
  using Math for uint256;
  using Token for address;
  using LibCompound for ICERC20;

  error InvalidMint(uint256 errorCode);
  error InvalidRedeem(uint256 errorCode);

  /// @notice Returns the comp token address
  function comp() public view virtual returns (IERC20);
  /// @notice Returns the cToken's address
  function cToken() public view virtual returns (ICERC20);
  /// @notice Returns the comptroller, the rewards controller
  function comptroller() public view virtual returns (IComptroller);
  function _asset() internal view virtual returns (address);

  /// @notice Performs a max approve to the cToken, so that we can deposit without any worries
  function maxApproveCToken() public {
    address asset = _asset();
    if (asset != Token.NATIVE_TOKEN) {
      IERC20(asset).forceApprove(address(cToken()), type(uint256).max);
    }
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
    tokens[1] = address(comp());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _isDepositTokenSupported(address depositToken) private view returns (bool) {
    return depositToken == _connector_asset() || depositToken == address(cToken());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal view virtual override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(cToken());
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxDeposit(address depositToken) internal view virtual override returns (uint256) {
    if (!_isDepositTokenSupported(depositToken)) {
      revert InvalidDepositToken(depositToken);
    }
    return comptroller().mintGuardianPaused(cToken()) ? 0 : type(uint256).max;
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
    (tokens, withdrawable) = _connector_totalBalances();
    uint256 cash = cToken().getCash();
    if (cash < withdrawable[0]) {
      withdrawable[0] = cash;
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
    tokens = _connector_allTokens();
    balances = new uint256[](2);
    balances[0] = cToken().viewUnderlyingBalanceOf(address(this));
    balances[1] = comp().balanceOf(address(this)) + comptroller().compAccrued(address(this));
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
  function _connector_deposit(
    address depositToken,
    uint256 depositAmount,
    bool takeFromCaller
  )
    internal
    virtual
    override
    returns (uint256 assetsDeposited)
  {
    ICERC20 cToken_ = cToken();
    uint256 balanceBefore = cToken_.viewUnderlyingBalanceOf(address(this));
    if (depositToken == _connector_asset()) {
      if (depositToken == Token.NATIVE_TOKEN) {
        // transfer native is the same as minting
        depositToken.transfer(address(cToken_), depositAmount);
      } else {
        if (takeFromCaller) {
          IERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);
        }
        uint256 errorCode = cToken_.mint(depositAmount);
        if (errorCode != 0) {
          revert InvalidMint(errorCode);
        }
      }
    } else if (depositToken == address(cToken_)) {
      if (takeFromCaller) {
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);
      }
    } else {
      revert InvalidDepositToken(depositToken);
    }
    uint256 balanceAfter = cToken_.viewUnderlyingBalanceOf(address(this));
    return balanceAfter - balanceBefore;
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
  {
    uint256 assets = toWithdraw[0];
    if (assets > 0) {
      address asset = _asset();
      uint256 errorCode = cToken().redeemUnderlying(assets);
      if (errorCode != 0) {
        revert InvalidRedeem(errorCode);
      }
      asset.transfer({ recipient: recipient, amount: assets });
    }
    IERC20 comp_ = comp();
    uint256 rewardAmount = toWithdraw[1];
    if (rewardAmount > 0) {
      uint256 rewardBalance = comp_.balanceOf(address(this));
      if (rewardBalance < rewardAmount) {
        // Claim all rewards
        address[] memory holders = new address[](1);
        holders[0] = address(this);
        ICERC20[] memory cTokens = new ICERC20[](1);
        cTokens[0] = cToken();
        comptroller().claimComp(holders, cTokens, false, true);
      }
      comp_.safeTransfer(recipient, rewardAmount);
    }
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
      uint256 balanceBefore = cToken_.viewUnderlyingBalanceOf(address(this));
      IERC20(cToken_).safeTransfer(recipient, shares);
      uint256 balanceAfter = cToken_.viewUnderlyingBalanceOf(address(this));
      balanceChanges[0] = balanceBefore - balanceAfter;
      actualWithdrawnTokens[0] = address(cToken_);
      actualWithdrawnAmounts[0] = shares;
    } else if (withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT) {
      // Note: we round down because if we were to round up, we might end up withdrawing more than the position's
      // balance, which would end up reverting on the vault
      uint256 shares = _convertAssetsToShares(toWithdraw[0], Math.Rounding.Floor);
      uint256 balanceBefore = cToken_.viewUnderlyingBalanceOf(address(this));
      IERC20(cToken_).safeTransfer(recipient, shares);
      uint256 balanceAfter = cToken_.viewUnderlyingBalanceOf(address(this));
      balanceChanges[0] = balanceBefore - balanceAfter;
      actualWithdrawnTokens[0] = address(cToken_);
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
    // Transfer cToken
    ICERC20 cToken_ = cToken();
    uint256 cTokenBalance = cToken_.balanceOf(address(this));
    IERC20(cToken_).safeTransfer(address(newStrategy), cTokenBalance);

    // Claim and transfer comp
    IERC20 comp_ = comp();
    address[] memory holders = new address[](1);
    holders[0] = address(this);
    ICERC20[] memory cTokens = new ICERC20[](1);
    cTokens[0] = cToken_;
    comptroller().claimComp(holders, cTokens, false, true);
    uint256 compBalance = comp_.balanceOf(address(this));
    comp_.safeTransfer(address(newStrategy), compBalance);

    return abi.encode(cTokenBalance, compBalance);
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

  // slither-disable-next-line dead-code
  function _convertAssetsToShares(uint256 assets, Math.Rounding rounding) private view returns (uint256) {
    return assets.mulDiv(1e18, cToken().viewExchangeRate(), rounding);
  }

  // slither-disable-next-line dead-code
  function _totalAssets() private view returns (uint256) {
    return _totalAssets(cToken());
  }

  // slither-disable-next-line dead-code
  function _totalAssets(ICERC20 cToken_) private view returns (uint256) {
    return cToken_.getCash() + cToken_.totalBorrows() - cToken_.totalReserves();
  }
}
