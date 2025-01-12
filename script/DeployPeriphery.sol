// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "./BaseDeployPeriphery.sol";
import { DeployManagers } from "./DeployManagers.sol";
import { DeployCompanion } from "./DeployCompanion.sol";
import { DeployStrategyRouter } from "./DeployStrategyRouter.sol";

contract DeployPeriphery is BaseDeployPeriphery, DeployManagers, DeployCompanion, DeployStrategyRouter {
  function run() external virtual override(DeployManagers, DeployCompanion, DeployStrategyRouter) {
    vm.startBroadcast();
    deployPeriphery();
    vm.stopBroadcast();
  }

  function deployPeriphery() internal {
    deployCompanion();
    deployManagers();
    deployStrategyRouter();
  }
}
