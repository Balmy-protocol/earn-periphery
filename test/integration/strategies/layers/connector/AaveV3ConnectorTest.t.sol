// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import {
  AaveV3Connector,
  SafeERC20,
  IERC20,
  IAaveV3Pool,
  IAaveV3Rewards,
  IAToken
} from "src/strategies/layers/connector/AaveV3Connector.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorInstance.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";

contract AaveV3ConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  IAToken internal aAaveV3Vault = IAToken(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE); // aDAI
  IERC20 internal aAaveV3Asset = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); // DAI
  IAaveV3Pool internal aAaveV3Pool = IAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); // Aave V3 LendingPool
  IAaveV3Rewards internal aAaveV3RewardsController = IAaveV3Rewards(0x929EC64c34a17401F460460D4B9390518E5B473e); // V3
    // Rewards

  // We need a holder for the aToken token
  address internal constant AAVE_V3_VAULT_HOLDER = 0xB2289E329D2F85F1eD31Adbb30eA345278F21bcf; // aDAI holder

  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _configureFork() internal override {
    uint256 optimismFork = vm.createFork(vm.rpcUrl("optimism"));
    vm.selectFork(optimismFork);

    vm.rollFork(20_000_000);

    vm.makePersistent(address(_farmToken())); // We need to make the farm token persistent for the next roll fork
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new AaveV3ConnectorInstance(aAaveV3Vault, aAaveV3Asset, aAaveV3Pool, aAaveV3RewardsController);
  }

  function _farmToken() internal view virtual override returns (address) {
    return address(aAaveV3Vault);
  }

  function testFork_rewardEmissionsPerSecondPerAsset() public {
    IAaveV3Rewards aAaveV3RewardsControllerMock = new AaveV3RewardsMock();

    AaveV3ConnectorInstance aaveV3Connector =
      new AaveV3ConnectorInstance(aAaveV3Vault, aAaveV3Asset, aAaveV3Pool, aAaveV3RewardsControllerMock);

    address[] memory asset = new address[](1);
    asset[0] = address(aAaveV3Vault);

    (uint256[] memory emissions, uint256[] memory multipliers) = aaveV3Connector.rewardEmissionsPerSecondPerAsset();

    assertEq(emissions.length, 1);
    assertEq(emissions[0], 1e10 * 1e30 / aAaveV3Vault.totalSupply());
    assertEq(multipliers.length, 1);
    assertEq(multipliers[0], 1e30);
  }

  function testFork_claimRewardTokens() public {
    // Mock the rewards controller to include the asset as a reward
    IAaveV3Rewards aAaveV3RewardsControllerMock =
      new AaveV3RewardsWithAssetRewardsMock(aAaveV3Asset, aAaveV3RewardsController);
    // Give rewards to the rewards controller for the asset
    _give(address(aAaveV3Asset), address(aAaveV3RewardsControllerMock), 10e10);

    AaveV3ConnectorInstance aaveV3Connector =
      new AaveV3ConnectorInstance(aAaveV3Vault, aAaveV3Asset, aAaveV3Pool, aAaveV3RewardsControllerMock);
    address[] memory asset = new address[](1);
    asset[0] = address(aAaveV3Vault);

    uint256 amountToClaimBefore =
      aAaveV3RewardsControllerMock.getUserRewards(asset, address(connector), connector.asset());

    (, uint256[] memory totalBalancesBefore) = aaveV3Connector.totalBalances();
    uint256 amountClaimed = aaveV3Connector.claimAndDepositAssetRewards();
    (, uint256[] memory totalBalancesAfter) = aaveV3Connector.totalBalances();

    uint256 amountToClaimAfter =
      aAaveV3RewardsControllerMock.getUserRewards(asset, address(connector), connector.asset());

    assertEq(totalBalancesAfter[0] - totalBalancesBefore[0], amountClaimed);
    assertEq(amountToClaimAfter, 0);
    assertEq(amountClaimed, amountToClaimBefore);
  }

  function _setBalance(address asset, address account, uint256 amount) internal override {
    if (asset == address(aAaveV3Vault)) {
      // We need to set the balance of the account to 0
      uint256 balance = IERC20(asset).balanceOf(account);
      if (balance > amount) {
        vm.prank(account);
        IERC20(asset).transfer(AAVE_V3_VAULT_HOLDER, balance - amount);
      } else if (balance < amount) {
        vm.prank(AAVE_V3_VAULT_HOLDER);
        IERC20(asset).transfer(account, amount - balance);
      }
    } else {
      return super._setBalance(asset, account, amount);
    }
  }

  function _generateYield() internal virtual override {
    // Roll the fork to generate some rewards
    vm.rollFork(123_000_000);
  }
}

contract AaveV3ConnectorInstance is BaseConnectorInstance, AaveV3Connector {
  IAToken internal immutable _vault;
  IERC20 internal immutable _vaultAsset;
  IAaveV3Pool internal immutable _pool;
  IAaveV3Rewards internal immutable _rewards;

  constructor(IAToken __vault, IERC20 __asset, IAaveV3Pool __pool, IAaveV3Rewards __rewards) initializer {
    _vault = __vault;
    _vaultAsset = __asset;
    _pool = __pool;
    _rewards = __rewards;
    _connector_init();
  }

  function pool() public view override returns (IAaveV3Pool) {
    return _pool;
  }

  function vault() public view override returns (IAToken) {
    return _vault;
  }

  function _asset() internal view override returns (IERC20) {
    return _vaultAsset;
  }

  function rewards() public view override returns (IAaveV3Rewards) {
    return _rewards;
  }

  function rewardEmissionsPerSecondPerAsset() external view returns (uint256[] memory, uint256[] memory) {
    return _connector_rewardEmissionsPerSecondPerAsset();
  }
}

contract AaveV3RewardsWithAssetRewardsMock is IAaveV3Rewards {
  using SafeERC20 for IERC20;

  IAaveV3Rewards internal rewards;
  IERC20 internal asset;

  constructor(IERC20 __asset, IAaveV3Rewards __rewards) {
    rewards = __rewards;
    asset = __asset;
  }

  function claimRewards(address[] calldata assets, uint256 amount, address to, address reward) external override {
    if (reward == address(asset)) {
      IERC20(reward).safeTransfer(to, amount);
      return;
    }
    rewards.claimRewards(assets, amount, to, reward);
  }

  function getRewardsByAsset(address _asset) external view override returns (address[] memory returnRewardsList) {
    address[] memory rewardsList = rewards.getRewardsByAsset(_asset);
    returnRewardsList = new address[](rewardsList.length + 1);
    for (uint256 i = 0; i < rewardsList.length; i++) {
      returnRewardsList[i] = rewardsList[i];
    }
    returnRewardsList[rewardsList.length] = address(asset);
  }

  function getUserRewards(
    address[] calldata assets,
    address user,
    address reward
  )
    external
    view
    override
    returns (uint256)
  {
    if (reward == address(asset)) {
      return IERC20(reward).balanceOf(address(this));
    }
    return rewards.getUserRewards(assets, user, reward);
  }

  function getRewardsData(address, address) external pure returns (uint256, uint256, uint256, uint256) {
    return (0, 0, 0, 0);
  }
}

contract AaveV3RewardsMock is IAaveV3Rewards {
  // solhint-disable-next-line no-empty-blocks
  function claimRewards(address[] calldata assets, uint256 amount, address to, address reward) external override { }

  function getRewardsByAsset(address) external pure override returns (address[] memory returnRewardsList) {
    returnRewardsList = new address[](1);
    returnRewardsList[0] = address(15);
  }

  function getUserRewards(address[] calldata, address, address) external pure override returns (uint256) {
    return 0;
  }

  function getRewardsData(address, address) external view returns (uint256, uint256, uint256, uint256) {
    return (0, 1e10, 0, block.timestamp + 10);
  }
}
