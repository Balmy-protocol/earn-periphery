// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IAToken, StrategyId, IEarnBalmyStrategy } from "../BaseDeployStrategies.sol";
import { FeeManager, Fees } from "src/strategies/layers/fees/external/FeeManager.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployStrategies is BaseDeployStrategies {
  function run() external {
    vm.startBroadcast();
    address aaveV3Pool = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address aaveV3Rewards = 0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44;
    address[] memory guardians = new address[](1);
    guardians[0] = 0x653c69a2dE94BeC3953C76c64763A1f1438207c6;

    address[] memory judges = new address[](1);
    judges[0] = getMsig();

    StrategyId strategyId;
    IEarnBalmyStrategy strategy;
    FeeManager feeManager = FeeManager(getDeployedAddress("V1_FEE_MANAGER"));

    // Tier 0 = default fees

    // USDC
    (strategy, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    console2.log("Strategy Tier 0 deployed: ", address(strategy));

    // Tier 1 = 7.5% performance fee + 3.75% rescue fee
    Fees memory tier1Fees = Fees(0, 0, 750, 375);

    // USDC
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier1Fees);
    console2.log("Strategy Tier 1 deployed: ", address(strategy));
    // Tier 2 = 5% performance fee + 2.5% rescue fee
    Fees memory tier2Fees = Fees(0, 0, 500, 250);
    // USDC
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier2Fees);
    console2.log("Strategy Tier 2 deployed: ", address(strategy));
    // Tier 3 = 2.5% performance fee + 1% rescue fee
    Fees memory tier3Fees = Fees(0, 0, 250, 100);

    // USDC
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier3Fees);
    console2.log("Strategy Tier 3 deployed: ", address(strategy));
    vm.stopBroadcast();
  }
}
