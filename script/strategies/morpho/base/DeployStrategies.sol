// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IERC4626, IEarnBalmyStrategy } from "../BaseDeployStrategies.sol";
import { Fees } from "src/strategies/layers/fees/external/FeeManager.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    vm.startBroadcast();
    deployPeriphery();
    deployMorphoStrategies();
    vm.stopBroadcast();
  }

  function deployMorphoStrategies() internal {
    address[] memory guardians = new address[](1);
    guardians[0] = 0x653c69a2dE94BeC3953C76c64763A1f1438207c6;

    address[] memory judges = new address[](1);
    judges[0] = getMsig();

    // Tier 0 = default fees

    // Moonwell Flagship ETH
    deployMorphoStrategy({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - moonwell flagship eth"
    });

    // Gauntlet USDC Prime
    deployMorphoStrategy({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - gauntlet usdc prime"
    });

    // Tier 1 = 7.5% performance fee + 3.75% rescue fee
    Fees memory tier1Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 750, rescueFee: 375 });

    // Moonwell Flagship ETH
    deployMorphoStrategy({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier1Fees,
      guard: "v1-t1",
      description: "strategy tier 1 - moonwell flagship eth"
    });

    // Gauntlet USDC Prime
    deployMorphoStrategy({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier1Fees,
      guard: "v1-t1",
      description: "strategy tier 1 - gauntlet usdc prime"
    });

    // Tier 2 = 5% performance fee + 2.5% rescue fee
    Fees memory tier2Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 500, rescueFee: 250 });

    // Moonwell Flagship ETH
    deployMorphoStrategy({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier2Fees,
      guard: "v1-t2",
      description: "strategy tier 2 - moonwell flagship eth"
    });

    // Gauntlet USDC Prime
    deployMorphoStrategy({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier2Fees,
      guard: "v1-t2",
      description: "strategy tier 2 - gauntlet usdc prime"
    });

    // Tier 3 = 2.5% performance fee + 1% rescue fee
    Fees memory tier3Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 250, rescueFee: 100 });

    // Moonwell Flagship ETH
    deployMorphoStrategy({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier3Fees,
      guard: "v1-t3",
      description: "strategy tier 3 - moonwell flagship eth"
    });

    // Gauntlet USDC Prime
    deployMorphoStrategy({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier3Fees,
      guard: "v1-t3",
      description: "strategy tier 3 - gauntlet usdc prime"
    });
  }
}
