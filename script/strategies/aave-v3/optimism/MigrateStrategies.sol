// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IAToken, StrategyId } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract MigrateStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    vm.startBroadcast();
    deployPeriphery();
    _deployAaveV3Strategies({ guard: "", version: "v3" });
    vm.stopBroadcast();
  }

  function _deployAaveV3Strategies(string memory guard, string memory version) internal {
    address aaveV3Pool = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address aaveV3Rewards = 0x929EC64c34a17401F460460D4B9390518E5B473e;

    address[] memory emptyGuardians = new address[](0);
    address[] memory emptyJudges = new address[](0);

    // WETH
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - weth - ", guard),
      initialStrategyId: StrategyId.wrap(1)
    });

    // Bridged USDC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x625E7708f30cA75bfd92586e17077590C60eb4cD),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - bridged usdc - ", guard),
      initialStrategyId: StrategyId.wrap(2)
    });

    // WBTC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x078f358208685046a11C85e8ad32895DED33A249),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - wbtc - ", guard),
      initialStrategyId: StrategyId.wrap(3)
    });

    // USDT
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x6ab707Aca953eDAeFBc4fD23bA73294241490620),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdt - ", guard),
      initialStrategyId: StrategyId.wrap(4)
    });

    // OP
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - op - ", guard),
      initialStrategyId: StrategyId.wrap(5)
    });

    // SUSD
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - susd - ", guard),
      initialStrategyId: StrategyId.wrap(6)
    });

    // USDC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdc - ", guard),
      initialStrategyId: StrategyId.wrap(7)
    });

    // DAI
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - dai - ", guard),
      initialStrategyId: StrategyId.wrap(8)
    });

    // LUSD
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x8Eb270e296023E9D92081fdF967dDd7878724424),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - lusd - ", guard),
      initialStrategyId: StrategyId.wrap(9)
    });
  }
}
