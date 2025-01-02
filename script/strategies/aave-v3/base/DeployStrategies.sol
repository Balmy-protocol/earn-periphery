// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies } from "../BaseDeployStrategies.sol";

contract DeployStrategies is BaseDeployStrategies {
  function run() external {
    vm.startBroadcast();

    address aaveV3Pool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address aaveV3Rewards = 0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44;

    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB, "USDC", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7, "WETH", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6, "cbBTC", true);

    vm.stopBroadcast();
  }
}
