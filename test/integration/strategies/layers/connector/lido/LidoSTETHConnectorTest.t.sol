// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BaseConnectorInstance } from "../base/BaseConnectorTest.t.sol";
import { BaseConnectorDelayedWithdrawalTest } from "../base/BaseConnectorDelayedWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "../base/BaseConnectorFarmTokenTest.t.sol";
import { IDelayedWithdrawalAdapter } from "src/interfaces/IDelayedWithdrawalAdapter.sol";
import { LidoSTETHConnector } from "src/strategies/layers/connector/lido/LidoSTETHConnector.sol";
import { DelayedWithdrawalAdapterMock } from "test/mocks/delayed-withdrawal-adapter/DelayedWithdrawalAdapterMock.sol";

contract LidoSTETHConnectorTest is BaseConnectorDelayedWithdrawalTest, BaseConnectorFarmTokenTest {
  // solhint-disable-next-line const-name-snakecase
  address internal constant _stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
  // solhint-disable-next-line const-name-snakecase
  address internal constant stETH_TOKEN_HOLDER = 0x93c4b944D05dfe6df7645A86cd2206016c51564D; // stETH Token Holder
  // solhint-disable-next-line const-name-snakecase
  address internal constant _QUEUE = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
  // solhint-disable-next-line no-empty-blocks

  bytes32 public constant DELAYED_WITHDRAWAL_MANAGER = keccak256("DELAYED_WITHDRAWAL_MANAGER");

  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _configureFork() internal override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);
    vm.rollFork(20_478_227);
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new LidoSTETHConnectorInstance(new DelayedWithdrawalAdapterMock());
  }

  function _farmToken() internal view virtual override returns (address) {
    return address(_stETH);
  }

  function _setBalance(address asset, address account, uint256 amount) internal override {
    if (asset == address(_stETH)) {
      // We need to set the balance of the account to 0
      uint256 balance = IERC20(asset).balanceOf(account);
      if (balance > amount) {
        vm.prank(account);
        IERC20(asset).transfer(stETH_TOKEN_HOLDER, balance - amount);
      } else if (balance < amount) {
        vm.prank(stETH_TOKEN_HOLDER);
        IERC20(asset).transfer(account, amount - balance);
      }
    } else {
      return super._setBalance(asset, account, amount);
    }
  }
}

contract LidoSTETHConnectorInstance is BaseConnectorInstance, LidoSTETHConnector {
  IDelayedWithdrawalAdapter internal immutable __delayedWithdrawalAdapter;

  constructor(IDelayedWithdrawalAdapter ___delayedWithdrawalAdapter) initializer {
    __delayedWithdrawalAdapter = ___delayedWithdrawalAdapter;
  }

  function _delayedWithdrawalAdapter() internal view override returns (IDelayedWithdrawalAdapter) {
    return __delayedWithdrawalAdapter;
  }
}
