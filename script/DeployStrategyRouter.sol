// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "./BaseDeployPeriphery.sol";
import { StrategyRouter } from "src/strategy-router/StrategyRouter.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployStrategyRouter is BaseDeployPeriphery {
  function run() external virtual {
    vm.startBroadcast();
    deployStrategyRouter();
    vm.stopBroadcast();
  }

  function deployStrategyRouter() public {
    address strategyRouter = deployContract("V1_SROUTER", abi.encodePacked(type(StrategyRouter).creationCode));
    console2.log("Strategy router:", strategyRouter);
  }
}
