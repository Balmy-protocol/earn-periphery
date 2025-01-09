// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IAToken, IEarnBalmyStrategy } from "../BaseDeployStrategies.sol";
import { console2 } from "forge-std/console2.sol";
import { Fees } from "src/strategies/layers/fees/external/FeeManager.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    vm.startBroadcast();
    deployPeriphery();
    deployAaveV3Strategies();
    vm.stopBroadcast();
  }

  function deployAaveV3Strategies() internal {
    address aaveV3Pool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address aaveV3Rewards = 0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44;
    address[] memory guardians = new address[](2);
    guardians[0] = 0x653c69a2dE94BeC3953C76c64763A1f1438207c6;
    guardians[1] = getMsig();

    address[] memory judges = new address[](1);
    judges[0] = getMsig();

    IEarnBalmyStrategy strategy;
    // Tier 0 = default fees
    // USDC
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0"
    });
    console2.log("strategy tier 0 - usdc", address(strategy));
    // WETH
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0"
    });
    console2.log("strategy tier 0 - weth", address(strategy));
    // cbBTC
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0"
    });
    console2.log("strategy tier 0 - cbbtc", address(strategy));
    // Tier 1 = 7.5% performance fee + 3.75% rescue fee
    Fees memory tier1Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 750, rescueFee: 375 });

    // USDC
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier1Fees,
      guard: "v1-t1"
    });
    console2.log("strategy tier 1 - usdc", address(strategy));

    // WETH
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier1Fees,
      guard: "v1-t1"
    });
    console2.log("strategy tier 1 - weth", address(strategy));
    // cbBTC
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier1Fees,
      guard: "v1-t1"
    });
    console2.log("strategy tier 1 - cbbtc", address(strategy));

    // Tier 2 = 5% performance fee + 2.5% rescue fee
    Fees memory tier2Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 500, rescueFee: 250 });
    // USDC
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier2Fees,
      guard: "v1-t2"
    });
    console2.log("strategy tier 2 - usdc", address(strategy));

    // WETH
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier2Fees,
      guard: "v1-t2"
    });
    console2.log("strategy tier 2 - weth", address(strategy));
    // Tier 3 = 2.5% performance fee + 1% rescue fee
    Fees memory tier3Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 250, rescueFee: 100 });

    // USDC
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier3Fees,
      guard: "v1-t3"
    });
    console2.log("strategy tier 3 - usdc", address(strategy));
    // WETH
    (strategy,) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier3Fees,
      guard: "v1-t3"
    });
    console2.log("strategy tier 3 - weth", address(strategy));
  }
}
