// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IERC4626, StrategyId } from "../BaseDeployStrategies.sol";
import { Fees } from "src/strategies/layers/fees/external/FeeManager.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    vm.startBroadcast();

    _deployMorphoStrategies({ guard: "", version: "v3" });
    vm.stopBroadcast();
  }

  function _deployMorphoStrategies(string memory guard, string memory version) internal {
    address[] memory moonwellRewardTokens = new address[](2);
    moonwellRewardTokens[0] = 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842; // $MORPHO
    moonwellRewardTokens[1] = 0xA88594D404727625A9437C3f886C7643872296AE; // $WELL

    address[] memory gauntletRewardTokens = new address[](1);
    gauntletRewardTokens[0] = 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842; // $MORPHO

    address[] memory emptyGuardians = new address[](0);
    address[] memory emptyJudges = new address[](0);

    // Tier 0 = default fees

    // Moonwell Flagship ETH
    deployMorphoStrategyWithId({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - moonwell flagship eth - ", guard),
      rewardTokens: moonwellRewardTokens,
      initialStrategyId: StrategyId.wrap(11)
    });

    // Gauntlet USDC Prime
    deployMorphoStrategyWithId({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - gauntlet usdc prime - ", guard),
      rewardTokens: gauntletRewardTokens,
      initialStrategyId: StrategyId.wrap(12)
    });

    // Tier 1 = 7.5% performance fee + 3.75% rescue fee
    Fees memory tier1Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 750, rescueFee: 375 });

    // Moonwell Flagship ETH
    deployMorphoStrategyWithId({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: tier1Fees,
      guard: bytes32(bytes(string.concat(version, "-t1", guard))),
      description: string.concat("strategy tier 1 - moonwell flagship eth - ", guard),
      rewardTokens: moonwellRewardTokens,
      initialStrategyId: StrategyId.wrap(13)
    });

    // Gauntlet USDC Prime
    deployMorphoStrategyWithId({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: tier1Fees,
      guard: bytes32(bytes(string.concat(version, "-t1", guard))),
      description: string.concat("strategy tier 1 - gauntlet usdc prime - ", guard),
      rewardTokens: gauntletRewardTokens,
      initialStrategyId: StrategyId.wrap(14)
    });

    // Tier 2 = 5% performance fee + 2.5% rescue fee
    Fees memory tier2Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 500, rescueFee: 250 });

    // Moonwell Flagship ETH
    deployMorphoStrategyWithId({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: tier2Fees,
      guard: bytes32(bytes(string.concat(version, "-t2", guard))),
      description: string.concat("strategy tier 2 - moonwell flagship eth - ", guard),
      rewardTokens: moonwellRewardTokens,
      initialStrategyId: StrategyId.wrap(15)
    });

    // Gauntlet USDC Prime
    deployMorphoStrategyWithId({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: tier2Fees,
      guard: bytes32(bytes(string.concat(version, "-t2", guard))),
      description: string.concat("strategy tier 2 - gauntlet usdc prime - ", guard),
      rewardTokens: gauntletRewardTokens,
      initialStrategyId: StrategyId.wrap(16)
    });

    // Tier 3 = 2.5% performance fee + 1% rescue fee
    Fees memory tier3Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 250, rescueFee: 100 });

    // Moonwell Flagship ETH
    deployMorphoStrategyWithId({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: tier3Fees,
      guard: bytes32(bytes(string.concat(version, "-t3", guard))),
      description: string.concat("strategy tier 3 - moonwell flagship eth - ", guard),
      rewardTokens: moonwellRewardTokens,
      initialStrategyId: StrategyId.wrap(17)
    });

    // Gauntlet USDC Prime
    deployMorphoStrategyWithId({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: tier3Fees,
      guard: bytes32(bytes(string.concat(version, "-t3", guard))),
      description: string.concat("strategy tier 3 - gauntlet usdc prime - ", guard),
      rewardTokens: gauntletRewardTokens,
      initialStrategyId: StrategyId.wrap(18)
    });
  }
}
