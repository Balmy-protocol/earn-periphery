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

interface IAaveV3Pool {
  function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IAaveV3Rewards {
  function claimRewards(address[] calldata assets, uint256 amount, address to, address reward) external;
  function getRewardsByAsset(address asset) external view returns (address[] memory);
  function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256);
}

// The AaveV3Connector is an implementation based on AaveV3ERC4626 to interact directly with Aave's Vaults (aTokens)
contract AaveV3Connector is BaseConnector {
  using SafeERC20 for IERC20;
  using Math for uint256;

  IERC20 internal immutable _vault;
  IERC20 internal immutable _asset;
  IAaveV3Pool internal immutable _pool;
  IAaveV3Rewards internal immutable _rewards;

  constructor(IERC20 vault, IERC20 asset, IAaveV3Pool pool, IAaveV3Rewards rewards) {
    _vault = vault;
    _asset = asset;
    _pool = pool;
    _rewards = rewards;
    maxApprovePool();
  }

  /// @notice Performs a max approve to the pool, so that we can deposit without any worries
  function maxApprovePool() public {
    _asset.forceApprove(address(_pool), type(uint256).max);
  }

  // slither-disable-next-line naming-convention,dead-code
  function claimAndDepositAssetRewards() external returns (uint256 amountToClaim) {
    address[] memory asset = new address[](1);
    asset[0] = address(_vault);
    amountToClaim = _rewards.getUserRewards(asset, address(this), _connector_asset());
    if (amountToClaim > 0) {
      _rewards.claimRewards(asset, amountToClaim, address(this), _connector_asset());
      _pool.supply(_connector_asset(), amountToClaim, address(this), 0);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_asset() internal view override returns (address) {
    return address(_asset);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_allTokens() internal view override returns (address[] memory tokens) {
    address[] memory rewardsList = _rewards.getRewardsByAsset(address(_vault));

    uint256 rewardsListLength = rewardsList.length;
    tokens = new address[](rewardsListLength + 1);
    tokens[0] = _connector_asset();
    uint256 amountOfValidTokens = 1;
    for (uint256 i = 0; i < rewardsListLength; ++i) {
      address rewardToken = rewardsList[i];
      if (rewardToken != _connector_asset()) {
        tokens[amountOfValidTokens] = rewardToken;
        amountOfValidTokens++;
      }
    }

    if (amountOfValidTokens != rewardsListLength + 1) {
      // Resize the array
      // slither-disable-next-line assembly
      assembly {
        mstore(tokens, amountOfValidTokens)
      }
    }
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
  function _connector_supportedWithdrawals() internal view override returns (IEarnStrategy.WithdrawalType[] memory) {
    return new IEarnStrategy.WithdrawalType[](_connector_allTokens().length); // IMMEDIATE
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isSpecialWithdrawalSupported(
    SpecialWithdrawalCode withdrawalCode
  )
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
    tokens = _connector_allTokens();
    balances = new uint256[](tokens.length);
    balances[0] = _vault.balanceOf(address(this));
    address[] memory asset = new address[](1);
    asset[0] = address(_vault);
    for (uint256 i = 1; i < tokens.length; ++i) {
      balances[i] = _rewards.getUserRewards(asset, address(this), tokens[i]);
    }
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
      _pool.supply(depositToken, depositAmount, address(this), 0);
      return depositAmount;
    } else if (depositToken == address(_vault)) {
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
    uint256 assets = toWithdraw[0];
    if (assets > 0) {
      // slither-disable-next-line unused-return
      _pool.withdraw(address(_asset), assets, recipient);
    }
    address[] memory asset = new address[](1);
    asset[0] = address(_vault);
    for (uint256 i = 1; i < tokens.length; ++i) {
      uint256 amountToWithdraw = toWithdraw[i];
      if (amountToWithdraw > 0) {
        _rewards.claimRewards(asset, amountToWithdraw, recipient, tokens[i]);
      }
    }
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
    if (
      withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT
        || withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT
    ) {
      withdrawalTypes = _connector_supportedWithdrawals();
      withdrawn = new uint256[](withdrawalTypes.length);
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
}
