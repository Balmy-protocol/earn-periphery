// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IERC4626 } from "../BaseDeployStrategies.sol";
import { Fees } from "src/strategies/layers/fees/external/FeeManager.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    address[] memory judges = new address[](1);
    address msig = getMsig();
    judges[0] = msig;

    vm.startBroadcast();
    deployPeriphery();
    // Warning: Morpho Factory was updated, so this will deploy the strategies with the new factory
    // TODO: Remove this when the new factory is deployed
    _deployMorphoStrategies(getGuardianArrayWithMsig(BALMY_GUARDIAN), judges, BALMY_GUARDIAN_TOS_GROUP, "");
    _deployMorphoStrategies(
      getGuardianArrayWithMsig(HYPERNATIVE_GUARDIAN), judges, HYPERNATIVE_GUARDIAN_TOS_GROUP, "hypernative"
    );
    vm.stopBroadcast();
  }

  function _deployMorphoStrategies(
    address[] memory guardians,
    address[] memory judges,
    bytes32 tosGroup,
    string memory guard
  )
    internal
  {
    address[] memory moonwellRewardTokens = new address[](2);
    moonwellRewardTokens[0] = 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842; // $MORPHO
    moonwellRewardTokens[1] = 0xA88594D404727625A9437C3f886C7643872296AE; // $WELL

    address[] memory gauntletRewardTokens = new address[](1);
    gauntletRewardTokens[0] = 0xBAa5CC21fd487B8Fcc2F632f3F4E8D37262a0842; // $MORPHO

    // Tier 0 = default fees

    // Moonwell Flagship ETH
    deployMorphoStrategy({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat("v1-t0", guard))),
      description: string.concat("strategy tier 0 - moonwell flagship eth - ", guard),
      rewardTokens: moonwellRewardTokens
    });

    // Gauntlet USDC Prime
    deployMorphoStrategy({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat("v1-t0", guard))),
      description: string.concat("strategy tier 0 - gauntlet usdc prime - ", guard),
      rewardTokens: gauntletRewardTokens
    });

    // Tier 1 = 7.5% performance fee + 3.75% rescue fee
    Fees memory tier1Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 750, rescueFee: 375 });

    // Moonwell Flagship ETH
    deployMorphoStrategy({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: tosGroup,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier1Fees,
      guard: bytes32(bytes(string.concat("v1-t1", guard))),
      description: string.concat("strategy tier 1 - moonwell flagship eth - ", guard),
      rewardTokens: moonwellRewardTokens
    });

    // Gauntlet USDC Prime
    deployMorphoStrategy({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: tosGroup,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier1Fees,
      guard: bytes32(bytes(string.concat("v1-t1", guard))),
      description: string.concat("strategy tier 1 - gauntlet usdc prime - ", guard),
      rewardTokens: gauntletRewardTokens
    });

    // Tier 2 = 5% performance fee + 2.5% rescue fee
    Fees memory tier2Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 500, rescueFee: 250 });

    // Moonwell Flagship ETH
    deployMorphoStrategy({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: tosGroup,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier2Fees,
      guard: bytes32(bytes(string.concat("v1-t2", guard))),
      description: string.concat("strategy tier 2 - moonwell flagship eth - ", guard),
      rewardTokens: moonwellRewardTokens
    });

    // Gauntlet USDC Prime
    deployMorphoStrategy({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: tosGroup,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier2Fees,
      guard: bytes32(bytes(string.concat("v1-t2", guard))),
      description: string.concat("strategy tier 2 - gauntlet usdc prime - ", guard),
      rewardTokens: gauntletRewardTokens
    });

    // Tier 3 = 2.5% performance fee + 1% rescue fee
    Fees memory tier3Fees = Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 250, rescueFee: 100 });

    // Moonwell Flagship ETH
    deployMorphoStrategy({
      mToken: IERC4626(0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1),
      tosGroup: tosGroup,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier3Fees,
      guard: bytes32(bytes(string.concat("v1-t3", guard))),
      description: string.concat("strategy tier 3 - moonwell flagship eth - ", guard),
      rewardTokens: moonwellRewardTokens
    });

    // Gauntlet USDC Prime
    deployMorphoStrategy({
      mToken: IERC4626(0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61),
      tosGroup: tosGroup,
      signerGroup: DEFAULT_SIGNER_GROUP,
      guardians: guardians,
      judges: judges,
      fees: tier3Fees,
      guard: bytes32(bytes(string.concat("v1-t3", guard))),
      description: string.concat("strategy tier 3 - gauntlet usdc prime - ", guard),
      rewardTokens: gauntletRewardTokens
    });
  }
}
