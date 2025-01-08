// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "./BaseDeployPeriphery.sol";
import { DeployManagers } from "./DeployManagers.sol";
import { DeployCompanion } from "./DeployCompanion.sol";
import { DeployStrategies as DeployAaveV3Strategies } from "./strategies/aave-v3/base/DeployStrategies.sol";
import { DeployStrategies as DeployMorphoStrategies } from "./strategies/morpho/base/DeployStrategies.sol";

contract DeployPeriphery is
  BaseDeployPeriphery,
  DeployManagers,
  DeployCompanion,
  DeployAaveV3Strategies,
  DeployMorphoStrategies
{
  function run() external override(DeployManagers, DeployCompanion, DeployAaveV3Strategies, DeployMorphoStrategies) {
    vm.startBroadcast();

    deployCompanion();
    deployManagers();
    deployAaveV3Strategies();
    deployMorphoStrategies();

    vm.stopBroadcast();
  }
}
