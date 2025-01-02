// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../BaseDeployStrategies.sol";
import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";

contract DeployStrategies is BaseDeployStrategies {
  function run() external {
    vm.startBroadcast(deployerPrivateKey);

    address aaveV3Pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address aaveV3Rewards = 0x929EC64c34a17401F460460D4B9390518E5B473e;

    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8, "WETH", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x625E7708f30cA75bfd92586e17077590C60eb4cD, "USDC.e", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x078f358208685046a11C85e8ad32895DED33A249, "WBTC", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x6ab707Aca953eDAeFBc4fD23bA73294241490620, "USDT", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf, "OP", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97, "sUSD", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5, "USDC", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE, "DAI", true);
    deployAaveV3Strategy(aaveV3Pool, aaveV3Rewards, 0x8Eb270e296023E9D92081fdF967dDd7878724424, "LUSD", true);

    vm.stopBroadcast();
  }
}
