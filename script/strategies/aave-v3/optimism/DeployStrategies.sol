// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IAToken } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    vm.startBroadcast();
    deployPeriphery();
    deployAaveV3Strategies();
    vm.stopBroadcast();
  }

  function deployAaveV3Strategies() internal {
    address aaveV3Pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address aaveV3Rewards = 0x929EC64c34a17401F460460D4B9390518E5B473e;

    address[] memory guardians = new address[](2);
    guardians[0] = 0x653c69a2dE94BeC3953C76c64763A1f1438207c6;
    guardians[1] = getMsig();

    address[] memory judges = new address[](1);
    judges[0] = getMsig();

    // WETH
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - weth"
    });

    // Bridged USDC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x625E7708f30cA75bfd92586e17077590C60eb4cD),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - bridged usdc"
    });

    // WBTC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x078f358208685046a11C85e8ad32895DED33A249),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - wbtc"
    });

    // USDT
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x6ab707Aca953eDAeFBc4fD23bA73294241490620),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - usdt"
    });

    // OP
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - op"
    });

    // SUSD
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - susd"
    });

    // USDC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - usdc"
    });

    // DAI
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - dai"
    });

    // LUSD
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x8Eb270e296023E9D92081fdF967dDd7878724424),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - lusd"
    });
  }
}
