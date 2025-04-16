// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, ICERC20, StrategyId } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    address[] memory judges = new address[](1);
    judges[0] = getMsig();

    vm.startBroadcast();
    deployPeriphery();
    _deployCompoundV3Strategies({ guard: "", version: "v2" });
    vm.stopBroadcast();
  }

  function _deployCompoundV3Strategies(string memory guard, string memory version) internal {
    address cometRewards = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1;
    address[] memory emptyGuardians = new address[](0);
    address[] memory emptyJudges = new address[](0);

    // USDC
    deployCompoundV3StrategyWithId({
      cometRewards: cometRewards,
      cToken: ICERC20(0xb125E6687d4313864e53df431d5425969c15Eb2F),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard),
      initialStrategyId: StrategyId.wrap(22)
    });

    // WETH
    deployCompoundV3StrategyWithId({
      cometRewards: cometRewards,
      cToken: ICERC20(0x46e6b214b524310239732D51387075E0e70970bf),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard),
      initialStrategyId: StrategyId.wrap(23)
    });
  }
}
