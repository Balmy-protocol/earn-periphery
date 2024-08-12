// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { AaveV3Connector, IERC20, IAaveV3Pool, IAaveV3Rewards } from "src/strategies/connector/AaveV3Connector.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorInstance.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";

contract AaveV3ConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  IERC20 internal aAaveV3Vault = IERC20(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE); // aDAI
  IERC20 internal aAaveV3Asset = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); // DAI
  IAaveV3Pool internal aAaveV3Pool = IAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD); // Aave V3 LendingPool
  IAaveV3Rewards internal aAaveV3RewardsController = IAaveV3Rewards(0x929EC64c34a17401F460460D4B9390518E5B473e); // Aave
    // V3 Rewards Controller

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

  function testFork_claimRewardTokens() public {
    AaveV3Connector aveV3Connector = AaveV3Connector(address(connector));
    address[] memory asset = new address[](1);
    asset[0] = address(aAaveV3Vault);
    // Deposit tokens
    _give(_farmToken(), address(connector), 10e18);
    connector.deposit(_farmToken(), 10e18);

    vm.rollFork(123_000_000); // Roll the fork to generate some rewards
    uint256 amountToClaim = aAaveV3RewardsController.getUserRewards(asset, address(connector), connector.asset());
    (, uint256[] memory balancesBefore) = connector.totalBalances();
    uint256 amountClaimed = aveV3Connector.claimAndDepositAssetRewards();
    (, uint256[] memory balancesAfter) = connector.totalBalances();
    assertEq(balancesAfter[0] - balancesBefore[0], amountToClaim);
    assertEq(amountClaimed, amountToClaim);
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

  function _rewardTokens() internal view virtual returns (address[] memory) {
    address[] memory tokens = connector.allTokens();
    address[] memory rewardsList = new address[](tokens.length - 1);
    for (uint256 i = 1; i < tokens.length; i++) {
      rewardsList[i - 1] = tokens[i];
    }
    return rewardsList;
  }

  function _generateYield(address recipient) internal virtual override {
    _setBalance(_farmToken(), recipient, 0);

    address[] memory rewardTokens = _rewardTokens();

    // Deposit tokens
    _give(_farmToken(), address(connector), 10e18);
    connector.deposit(_farmToken(), 10e18);

    vm.rollFork(123_000_000); // Roll the fork to generate some rewards

    for (uint256 i; i < rewardTokens.length; ++i) {
      // Remove reward tokens from recipient, only to avoid to save previous rewards balance
      _setBalance(rewardTokens[i], recipient, 0);
    }
  }
}

contract AaveV3ConnectorInstance is BaseConnectorInstance, AaveV3Connector {
  constructor(
    IERC20 __vault,
    IERC20 __asset,
    IAaveV3Pool __pool,
    IAaveV3Rewards __rewards
  )
    AaveV3Connector(__vault, __asset, __pool, __rewards)
  { }
}
