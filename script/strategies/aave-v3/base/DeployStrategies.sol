// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IAToken, StrategyId } from "../BaseDeployStrategies.sol";
import { FeeManager, Fees } from "src/strategies/layers/fees/external/FeeManager.sol";

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
    FeeManager feeManager = FeeManager(getDeployedAddress("V1_FEE_MANAGER"));

    // Tier 0 = default fees

    // USDC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });

    // WETH
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });

    // cbBTC
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });

    // Tier 1 = 7.5% performance fee + 3.75% rescue fee
    Fees memory tier1Fees = Fees(750, 375, 0, 0);

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

    // WETH
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier1Fees);

    // cbBTC
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier1Fees);

    // Tier 2 = 5% performance fee + 2.5% rescue fee
    Fees memory tier2Fees = Fees(500, 250, 0, 0);
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

    // WETH
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier2Fees);

    // cbBTC
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier2Fees);

    // Tier 3 = 2.5% performance fee + 1% rescue fee
    Fees memory tier3Fees = Fees(250, 100, 0, 0);

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

    // WETH
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier3Fees);

    // cbBTC
    (, strategyId) = deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges
    });
    feeManager.updateFees(strategyId, tier3Fees);

    vm.stopBroadcast();
  }
}
