// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, ICERC20 } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    vm.startBroadcast();
    deployPeriphery();
    deployAaveV3Strategies();
    vm.stopBroadcast();
  }

  function deployAaveV3Strategies() internal {
    address cometRewards = 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae;

    address[] memory guardians = new address[](2);
    guardians[0] = 0x653c69a2dE94BeC3953C76c64763A1f1438207c6;
    guardians[1] = getMsig();

    address[] memory judges = new address[](1);
    judges[0] = getMsig();

    // USDC
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      asset: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
      cToken: ICERC20(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - usdc"
    });

    // USDT
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      asset: 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9,
      cToken: ICERC20(0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - usdt"
    });

    // WETH
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      asset: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
      cToken: ICERC20(0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - weth"
    });
  }
}
