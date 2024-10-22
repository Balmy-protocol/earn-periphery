// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorTest.t.sol";
import { BaseConnectorDelayedWithdrawalTest } from "./base/BaseConnectorDelayedWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";
import { IDelayedWithdrawalAdapter } from "src/interfaces/IDelayedWithdrawalAdapter.sol";
import { ERC4626DelayedConnector } from "src/strategies/layers/connector/ERC4626DelayedConnector.sol";
import { DelayedWithdrawalAdapterMock } from
  "../../../../mocks/delayed-withdrawal-adapter/DelayedWithdrawalAdapterMock.sol";

contract ERC4626DelayedConnectorTest is BaseConnectorDelayedWithdrawalTest, BaseConnectorFarmTokenTest {
  address internal constant FARM_TOKEN_HOLDER = 0x18451C199Dea9563DE64A87b43045b0554E05ECD;
  address internal constant FARM_TOKEN = 0x305F25377d0a39091e99B975558b1bdfC3975654;

  bytes32 public constant DELAYED_WITHDRAWAL_MANAGER = keccak256("DELAYED_WITHDRAWAL_MANAGER");

  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _configureFork() internal override {
    uint256 polygonFork = vm.createFork(vm.rpcUrl("polygon"));
    vm.selectFork(polygonFork);
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new ERC4626DelayedConnectorInstance(new DelayedWithdrawalAdapterMock(), FARM_TOKEN);
  }

  function _farmToken() internal view virtual override returns (address) {
    return address(FARM_TOKEN);
  }

  function _setBalance(address asset, address account, uint256 amount) internal override {
    if (asset == address(FARM_TOKEN)) {
      // We need to set the balance of the account to 0
      uint256 balance = IERC20(asset).balanceOf(account);
      if (balance > amount) {
        vm.prank(account);
        IERC20(asset).transfer(FARM_TOKEN_HOLDER, balance - amount);
      } else if (balance < amount) {
        vm.prank(FARM_TOKEN_HOLDER);
        IERC20(asset).transfer(account, amount - balance);
      }
    } else {
      return super._setBalance(asset, account, amount);
    }
  }
}

contract ERC4626DelayedConnectorInstance is BaseConnectorInstance, ERC4626DelayedConnector {
  IDelayedWithdrawalAdapter internal immutable __delayedWithdrawalAdapter;
  address internal immutable farmToken;

  constructor(IDelayedWithdrawalAdapter ___delayedWithdrawalAdapter, address farmToken_) initializer {
    farmToken = farmToken_;
    __delayedWithdrawalAdapter = ___delayedWithdrawalAdapter;
    _connector_init();
  }

  function _delayedWithdrawalAdapter() internal view override returns (IDelayedWithdrawalAdapter) {
    return __delayedWithdrawalAdapter;
  }

  function ERC4626Vault() public view virtual override returns (IERC4626) {
    return IERC4626(farmToken);
  }

  function _asset() internal view virtual override returns (IERC20) {
    return IERC20(ERC4626Vault().asset());
  }
}
