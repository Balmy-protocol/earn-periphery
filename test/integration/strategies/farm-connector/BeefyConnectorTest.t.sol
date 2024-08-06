// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BeefyConnector, IVault } from "src/strategies/connector/BeefyConnector.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorTest.t.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";

contract BeefyConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  IVault internal aBeefyVault = IVault(0x0383E88A19E5c387FeBafbF51E5bA642d2ad8bE0);

  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _configureFork() internal override {
    uint256 bnbFork = vm.createFork(vm.rpcUrl("bnb_smart_chain"));
    vm.selectFork(bnbFork);
    vm.rollFork(41_132_256);
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new BeefyConnectorInstance(aBeefyVault);
  }

  function _farmToken() internal view virtual override returns (address) {
    return address(aBeefyVault);
  }
}

contract BeefyConnectorInstance is BaseConnectorInstance, BeefyConnector {
  constructor(IVault _vault) BeefyConnector(_vault) { }
}
