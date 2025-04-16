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

    // LUSD
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x8ffDf2DE812095b1D19CB146E4c004587C0A0692),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - lusd - ", guard),
      initialStrategyId: StrategyId.wrap(40)
    });

    // FRAX
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
      description: string.concat("strategy tier 0 - frax - ", guard),
      initialStrategyId: StrategyId.wrap(41)
    });

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
      initialStrategyId: StrategyId.wrap(42)
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
      initialStrategyId: StrategyId.wrap(43)
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
      initialStrategyId: StrategyId.wrap(44)
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
      initialStrategyId: StrategyId.wrap(45)
    });

    // ARB
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x6533afac2E7BCCB20dca161449A13A32D391fb00),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - arb - ", guard),
      initialStrategyId: StrategyId.wrap(46)
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
      initialStrategyId: StrategyId.wrap(47)
    });

    // USDC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x724dc807b04555b71ed48a6896b6F41593b8C637),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdc - ", guard),
      initialStrategyId: StrategyId.wrap(48)
    });

    // GHO
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xeBe517846d0F36eCEd99C735cbF6131e1fEB775D),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - gho - ", guard),
      initialStrategyId: StrategyId.wrap(49)
    });
  }
}
