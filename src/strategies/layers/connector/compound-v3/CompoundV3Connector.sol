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
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { CometRewardsTracker } from "./CometRewardsTracker.sol";
import { ICometRewards } from "./ICometRewards.sol";
import { LibComet } from "./LibComet.sol";
import { ICERC20 } from "./ICERC20.sol";

abstract contract CompoundV3Connector is BaseConnector, Initializable {
  using SafeERC20 for IERC20;
  using Math for uint256;
  using Token for address;

  /// @notice The id for the Comet Rewards Tracker
  bytes32 public constant COMET_REWARDS_TRACKER = keccak256("COMET_REWARDS_TRACKER");

  /// @notice Returns the cToken's address
  function cToken() public view virtual returns (ICERC20);
  /// @notice Returns the rewards controller
  function cometRewards() public view virtual returns (ICometRewards);

  function _asset() internal view virtual returns (address);

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

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
    address rewardToken = LibComet.getRewardsConfig(cometRewards(), cToken()).token;
    if (rewardToken == address(0)) {
      tokens = new address[](1);
    } else {
      tokens = new address[](2);
      tokens[1] = rewardToken;
    }
    tokens[0] = _connector_asset();
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
    if (tokens.length > 1) {
      // We need to check if the comet rewards has the claimable amount of the reward token in its balance
      withdrawable[1] = Math.min(withdrawable[1], IERC20(tokens[1]).balanceOf(address(cometRewards())));
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
    ICERC20 cToken_ = cToken();
    (address rewardToken, uint256 rewardAmount) =
      _getRewardsTracker().getRewardsOwed(cometRewards(), cToken_, address(this));
    if (rewardToken == address(0)) {
      tokens = new address[](1);
      balances = new uint256[](1);
    } else {
      tokens = new address[](2);
      balances = new uint256[](2);
      tokens[1] = rewardToken;
      balances[1] = IERC20(rewardToken).balanceOf(address(this)) + rewardAmount;
    }
    tokens[0] = _connector_asset();
    balances[0] = cToken_.balanceOf(address(this));
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
    if (takeFromCaller) {
      IERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);
    }
    ICERC20 cToken_ = cToken();
    if (depositToken == _connector_asset()) {
      uint256 balanceBefore = cToken_.balanceOf(address(this));
      cToken_.supply(depositToken, depositAmount);
      uint256 balanceAfter = cToken_.balanceOf(address(this));
      return balanceAfter - balanceBefore;
    } else if (depositToken == address(cToken_)) {
      return depositAmount;
    } else {
      revert InvalidDepositToken(depositToken);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_withdraw(
    uint256,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    virtual
    override
  {
    ICERC20 cToken_ = cToken();
    uint256 assets = toWithdraw[0];
    if (assets > 0) {
      address asset = tokens[0];
      cToken_.withdraw(asset, assets);
      asset.transfer({ recipient: recipient, amount: assets });
    }

    if (tokens.length > 1) {
      IERC20 rewardToken = IERC20(tokens[1]);
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
    ICometRewards cometRewards_ = cometRewards();
    uint256 rewardBalance = 0;
    (address rewardToken, uint256 rewardAmount) =
      _getRewardsTracker().getRewardsOwed(cometRewards_, cToken_, address(this));
    if (rewardToken != address(0)) {
      if (rewardAmount > 0) {
        cometRewards_.claimTo(address(cToken_), address(this), address(this), true);
      }
      rewardBalance = IERC20(rewardToken).balanceOf(address(this));
      IERC20(rewardToken).safeTransfer(address(newStrategy), rewardBalance);
    }

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

  function _getRewardsTracker() private view returns (CometRewardsTracker) {
    return CometRewardsTracker(globalRegistry().getAddressOrFail(COMET_REWARDS_TRACKER));
  }
}
