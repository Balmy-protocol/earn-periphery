// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BeefyConnector, IBeefyVault } from "src/strategies/connector/BeefyConnector.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorTest.t.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";

contract BeefyConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  IBeefyVault internal aBeefyVault = IBeefyVault(0x01D9cfB8a9D43013a1FdC925640412D8d2D900F0);

  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _configureFork() internal override {
    uint256 optimismFork = vm.createFork(vm.rpcUrl("optimism"));
    vm.selectFork(optimismFork);
    vm.rollFork(120_000_000);
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new BeefyConnectorInstance(aBeefyVault);
  }

  function _farmToken() internal view virtual override returns (address) {
    return address(aBeefyVault);
  }
}

contract BeefyConnectorInstance is BaseConnectorInstance, BeefyConnector {
  constructor(IBeefyVault _vault) BeefyConnector(_vault) { }
}
