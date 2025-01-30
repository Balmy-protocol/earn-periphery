// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, ICERC20 } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    address[] memory guardians = new address[](2);
    address[] memory judges = new address[](1);

    address msig = getMsig();
    guardians[0] = 0x653c69a2dE94BeC3953C76c64763A1f1438207c6;
    guardians[1] = msig;
    judges[0] = msig;

    vm.startBroadcast();
    deployPeriphery();
    _deployCompoundV3Strategies(guardians, judges);
    vm.stopBroadcast();
  }

  function _deployCompoundV3Strategies(address[] memory guardians, address[] memory judges) internal {
    address cometRewards = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;

    // USDC
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0xb125E6687d4313864e53df431d5425969c15Eb2F),
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: "v1-t0",
      description: "strategy tier 0 - usdc"
    });

    // WETH
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0x46e6b214b524310239732D51387075E0e70970bf),
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
