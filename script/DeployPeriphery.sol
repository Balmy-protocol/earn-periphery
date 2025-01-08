// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "./BaseDeployPeriphery.sol";
import { DeployManagers } from "./DeployManagers.sol";
import { DeployCompanion } from "./DeployCompanion.sol";
//import { DeployStrategies } from "./strategies/aave-v3/base/DeployStrategies.sol";
import { DeployStrategies } from "./strategies/morpho/base/DeployStrategies.sol";

contract DeployPeriphery is BaseDeployPeriphery, DeployManagers, DeployCompanion, DeployStrategies {
  function run() external override(DeployManagers, DeployCompanion, DeployStrategies) {
    vm.startBroadcast();

    deployCompanion();
    deployManagers();
    deployStrategies();

    vm.stopBroadcast();
  }
}
