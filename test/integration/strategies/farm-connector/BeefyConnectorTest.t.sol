// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { BeefyConnector } from "src/strategies/connector/BeefyConnector.sol";
import { IVault } from "@beefy-contracts/interfaces/beefy/IVault.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorTest.t.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";

contract BeefyConnectorTest is BaseConnectorImmediateWithdrawalTest {
  IVault internal aBeefyVault = IVault(0x0383E88A19E5c387FeBafbF51E5bA642d2ad8bE0);

  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _configureFork() internal override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("bnb_smart_chain"));
    vm.selectFork(mainnetFork);
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new BeefyConnectorInstance(aBeefyVault);
  }
}

contract BeefyConnectorInstance is BaseConnectorInstance, BeefyConnector {
  constructor(IVault _vault) BeefyConnector(_vault) { }
}
