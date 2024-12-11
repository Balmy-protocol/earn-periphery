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

interface ICometRewards {
  struct RewardConfig {
    address token;
    uint64 rescaleFactor;
    bool shouldUpscale;
  }
  
  function rewardConfig(address) external view returns (RewardConfig memory);
  function claim(address comet, address src, bool shouldAccrue) external;
  function claimTo(address comet, address src, address to, bool shouldAccrue) external;
}

abstract contract CompoundV3Connector is BaseConnector, Initializable {
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
    address rewardToken = address(cometRewards().rewardConfig(address(cToken())).token);
    tokens = new address[](rewardToken == address(0) ? 1 : 2);
    tokens[0] = _connector_asset();
    if (rewardToken != address(0)) {
      tokens[1] = rewardToken;
    }
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
    return new IEarnStrategy.WithdrawalType[](_connector_allTokens().length);
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
    IERC20 cToken_ = cToken();
    ICometRewards.RewardConfig memory config = cometRewards().rewardConfig(address(cToken_));
    tokens = _connector_allTokens();
    balances = new uint256[](tokens.length);
    balances[0] = cToken_.balanceOf(address(this));
    if (config.token != address(0)) {
      balances[1] = IERC20(config.token).balanceOf(address(this)); // TODO: calculate unclaimed rewards
    }
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
    ICERC20 cToken_ = cToken();
    if (depositToken == _connector_asset()) {
      uint256 balanceBefore = cToken_.balanceOf(address(this));
      cToken_.supply(depositToken, (depositAmount));
      uint256 balanceAfter = cToken_.balanceOf(address(this));
      return balanceAfter - balanceBefore;
    } else if (depositToken == address(cToken_)) {
      return (depositAmount);
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
    ICERC20 cToken_ = cToken();
    uint256 assets = (toWithdraw[0]);
    if (assets > 0) {
      address asset = _asset();
      cToken_.withdraw(asset, assets);
      asset.transfer({ recipient: recipient, amount: assets });
    }

    IERC20 rewardToken = IERC20(cometRewards().rewardConfig(address(cToken_)).token);
    if (address(rewardToken) != address(0)) {
      uint256 rewardAmount = toWithdraw[1];
      if (rewardAmount > 0) {
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        if (rewardBalance < rewardAmount) {
          // Claim all rewards
          address[] memory holders = new address[](1);
          holders[0] = address(this);
          ICERC20[] memory cTokens = new ICERC20[](1);
          cTokens[0] = cToken_;
          cometRewards().claimTo(address(cToken_), address(this), address(this), true);
        }
        rewardToken.safeTransfer(recipient, rewardAmount);
      }
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
    if (
      withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT
        || withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT
    ) {
      IERC20 cToken_ = cToken();
      balanceChanges = new uint256[](_connector_allTokens().length);
      actualWithdrawnTokens = new address[](1);
      actualWithdrawnAmounts = new uint256[](1);
      result = "";
      uint256 assets = toWithdraw[0];
      cToken_.safeTransfer(recipient, assets);
      balanceChanges[0] = assets;
      actualWithdrawnTokens[0] = address(cToken_);
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
    virtual
    override
    returns (bytes memory)
  {
    // Transfer cToken
    ICERC20 cToken_ = cToken();
    uint256 cTokenBalance = cToken_.balanceOf(address(this));
    IERC20(cToken_).safeTransfer(address(newStrategy), cTokenBalance);

    // Claim and transfer rewards
    IERC20 rewardToken = IERC20(cometRewards().rewardConfig(address(cToken_)).token);
    cometRewards().claimTo(address(cToken_), address(this), address(this), true);
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
}
