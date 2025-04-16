// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IAToken, StrategyId } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract MigrateStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    vm.startBroadcast();
    _deployAaveV3Strategies({ guard: "", version: "v3" });
    vm.stopBroadcast();
  }

  function _deployAaveV3Strategies(string memory guard, string memory version) internal {
    address aaveV3Pool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address aaveV3Rewards = 0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44;

    address[] memory emptyGuardians = new address[](0);
    address[] memory emptyJudges = new address[](0);

    // Tier 0 = default fees
    // USDC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdc - ", guard),
      initialStrategyId: StrategyId.wrap(1)
    });
    // WETH
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - weth - ", guard),
      initialStrategyId: StrategyId.wrap(2)
    });
    // cbBTC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - cbbtc - ", guard),
      initialStrategyId: StrategyId.wrap(3)
    });
    // Tier 1 = 7.5% performance fee + 3.75% rescue fee

    // USDC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t1", guard))),
      description: string.concat("strategy tier 1 - usdc - ", guard),
      initialStrategyId: StrategyId.wrap(4)
    });

    // WETH
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t1", guard))),
      description: string.concat("strategy tier 1 - weth - ", guard),
      initialStrategyId: StrategyId.wrap(5)
    });
    // cbBTC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t1", guard))),
      description: string.concat("strategy tier 1 - cbbtc - ", guard),
      initialStrategyId: StrategyId.wrap(6)
    });

    // Tier 2 = 5% performance fee + 2.5% rescue fee

    // cbBTC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t2", guard))),
      description: string.concat("strategy tier 2 - cbbtc - ", guard),
      initialStrategyId: StrategyId.wrap(20)
    });
    // Tier 3 = 2.5% performance fee + 1% rescue fee

    // cbBTC
    deployAaveV3StrategyWithId({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t3", guard))),
      description: string.concat("strategy tier 3 - cbbtc - ", guard),
      initialStrategyId: StrategyId.wrap(21)
    });
  }
}
