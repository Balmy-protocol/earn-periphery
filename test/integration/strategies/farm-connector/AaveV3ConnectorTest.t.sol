// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { AaveV3Connector, IERC20, IAaveV3Pool, IAaveV3Rewards } from "src/strategies/connector/AaveV3Connector.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorTest.t.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";
import { BaseConnectorRewardTokenTest } from "./base/BaseConnectorRewardTokenTest.t.sol";

contract AaveV3ConnectorTest is
  BaseConnectorImmediateWithdrawalTest,
  BaseConnectorFarmTokenTest,
  BaseConnectorRewardTokenTest
{
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

  function _rewardTokens() internal view virtual override returns (address[] memory) {
    return aAaveV3RewardsController.getRewardsByAsset(address(aAaveV3Vault));
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
