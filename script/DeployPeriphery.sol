// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "./BaseDeployPeriphery.sol";
import { DeployManagers } from "./DeployManagers.sol";
import { DeployCompanion } from "./DeployCompanion.sol";

contract DeployPeriphery is BaseDeployPeriphery, DeployManagers, DeployCompanion {
  function run() external override(DeployManagers, DeployCompanion) {
    vm.startBroadcast();

    deployCompanion();
    deployManagers();

    vm.stopBroadcast();
  }
}
