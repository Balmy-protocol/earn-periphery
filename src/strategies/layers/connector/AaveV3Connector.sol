// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  BaseConnector,
  IEarnStrategy,
  SpecialWithdrawalCode,
  IDelayedWithdrawalAdapter,
  StrategyId
} from "./base/BaseConnector.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";

interface IAToken is IERC20 {
  function scaledTotalSupply() external view returns (uint256);
  // slither-disable-next-line naming-convention
  function UNDERLYING_ASSET_ADDRESS() external returns (address);
}

interface IAaveV3Pool {
  function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IAaveV3Rewards {
  function claimRewards(address[] calldata assets, uint256 amount, address to, address reward) external;
  function getRewardsByAsset(address asset) external view returns (address[] memory);
  function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256);
  /**
   * @dev Returns the configuration of the distribution reward for a certain asset
   * @param asset The incentivized asset
   * @param reward The reward token of the incentivized asset
   * @return The index of the asset distribution
   * @return The emission per second of the reward distribution
   * @return The timestamp of the last update of the index
   * @return The timestamp of the distribution end
   *
   */
  function getRewardsData(address asset, address reward) external view returns (uint256, uint256, uint256, uint256);
}

// The AaveV3Connector is an implementation based on AaveV3ERC4626 to interact directly with Aave's Vaults (aTokens)
abstract contract AaveV3Connector is BaseConnector, Initializable {
  using SafeERC20 for IERC20;
  using Math for uint256;

  /// @notice Returns the pool's address
  function pool() public view virtual returns (IAaveV3Pool);
  /// @notice Returns the aToken's address
  function aToken() public view virtual returns (IAToken);
  /// @notice Returns the rewards contractt's address
  function rewards() public view virtual returns (IAaveV3Rewards);
  function _asset() internal view virtual returns (IERC20);

  /// @notice Performs a max approve to the pool, so that we can deposit without any worries
  function maxApprovePool() public {
    _asset().forceApprove(address(pool()), type(uint256).max);
  }

  /// @notice Checks if there are rewards generated where the asset is the same as the reward token, claims them, and
  /// deposits them
  function claimAndDepositAssetRewards() external returns (uint256 amountToClaim) {
    IAaveV3Rewards rewards_ = rewards();
    address[] memory asset = new address[](1);
    asset[0] = address(aToken());
    amountToClaim = rewards_.getUserRewards(asset, address(this), _connector_asset());
    if (amountToClaim > 0) {
      rewards_.claimRewards(asset, amountToClaim, address(this), _connector_asset());
      pool().supply(_connector_asset(), amountToClaim, address(this), 0);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_init() internal onlyInitializing {
    maxApprovePool();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_asset() internal view override returns (address) {
    return address(_asset());
  }

  // slither-disable-start assembly
  // slither-disable-next-line naming-convention,dead-code,assembly
  function _connector_allTokens() internal view override returns (address[] memory tokens) {
    address[] memory rewardsList = rewards().getRewardsByAsset(address(aToken()));

    uint256 rewardsListLength = rewardsList.length;
    tokens = new address[](rewardsListLength + 1);
    tokens[0] = _connector_asset();
    uint256 amountOfValidTokens = 1;
    for (uint256 i = 0; i < rewardsListLength; ++i) {
      address rewardToken = rewardsList[i];
      if (rewardToken != _connector_asset()) {
        tokens[amountOfValidTokens++] = rewardToken;
      }
    }

    if (amountOfValidTokens != rewardsListLength + 1) {
      // Resize the array
      // solhint-disable-next-line no-inline-assembly
      assembly {
        mstore(tokens, amountOfValidTokens)
      }
    }
  }
  // slither-disable-end assembly

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
  function _connector_supportedWithdrawals() internal view override returns (IEarnStrategy.WithdrawalType[] memory) {
    return new IEarnStrategy.WithdrawalType[](_connector_allTokens().length); // IMMEDIATE
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
    IERC20 vault_ = aToken();
    IAaveV3Rewards rewards_ = rewards();
    tokens = _connector_allTokens();
    balances = new uint256[](tokens.length);
    balances[0] = vault_.balanceOf(address(this));
    address[] memory asset = new address[](1);
    asset[0] = address(vault_);
    for (uint256 i = 1; i < tokens.length; ++i) {
      balances[i] = rewards_.getUserRewards(asset, address(this), tokens[i]);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_delayedWithdrawalAdapter(address) internal pure override returns (IDelayedWithdrawalAdapter) {
    return IDelayedWithdrawalAdapter(address(0));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_assetYieldCoefficient() internal view virtual override returns (uint256) {
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
    view
    override
    returns (uint256[] memory emissions, uint256[] memory multipliers)
  {
    IAaveV3Rewards rewardsController = rewards();
    IAToken aToken_ = aToken();
    uint256 totalAssets = aToken_.totalSupply();
    address[] memory rewardsList = rewardsController.getRewardsByAsset(address(aToken_));
    emissions = new uint256[](rewardsList.length);
    multipliers = new uint256[](rewardsList.length);
    if (totalAssets > 0) {
      for (uint256 i; i < rewardsList.length; ++i) {
        // slither-disable-next-line unused-return
        (, uint256 emissionPerSecond,, uint256 distributionEnd) =
          rewardsController.getRewardsData(address(aToken_), rewardsList[i]);
        // slither-disable-next-line timestamp
        if (block.timestamp <= distributionEnd) {
          multipliers[i] = 1e30;
          emissions[i] = emissionPerSecond.mulDiv(1e30, totalAssets, Math.Rounding.Floor);
        }
      }
    }
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
      pool().supply(depositToken, depositAmount, address(this), 0);
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
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    IAaveV3Rewards rewards_ = rewards();
    uint256 assets = toWithdraw[0];
    if (assets > 0) {
      // slither-disable-next-line unused-return
      pool().withdraw(address(_asset()), assets, recipient);
    }
    address[] memory asset = new address[](1);
    asset[0] = address(aToken());
    for (uint256 i = 1; i < tokens.length; ++i) {
      uint256 amountToWithdraw = toWithdraw[i];
      if (amountToWithdraw > 0) {
        rewards_.claimRewards(asset, amountToWithdraw, recipient, tokens[i]);
      }
    }
    return new IEarnStrategy.WithdrawalType[](tokens.length);
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
      balanceChanges = new uint256[](_connector_allTokens().length);
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
