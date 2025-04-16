// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, ICERC20, StrategyId } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    vm.startBroadcast();
    deployPeriphery();
    _deployCompoundV3Strategies({ guard: "", version: "v3" });
    vm.stopBroadcast();
  }

  function _deployCompoundV3Strategies(string memory guard, string memory version) internal {
    address[] memory emptyGuardians = new address[](0);
    address[] memory emptyJudges = new address[](0);

    address cometRewards = 0x443EA0340cb75a160F31A440722dec7b5bc3C2E9;

    // USDC
    deployCompoundV3StrategyWithId({
      cometRewards: cometRewards,
      cToken: ICERC20(0x2e44e174f7D53F0212823acC11C01A11d58c5bCB),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard),
      initialStrategyId: StrategyId.wrap(10)
    });

    // USDT
    deployCompoundV3StrategyWithId({
      cometRewards: cometRewards,
      cToken: ICERC20(0x995E394b8B2437aC8Ce61Ee0bC610D617962B214),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard),
      initialStrategyId: StrategyId.wrap(11)
    });

    // WETH
    deployCompoundV3StrategyWithId({
      cometRewards: cometRewards,
      cToken: ICERC20(0xE36A30D249f7761327fd973001A32010b521b6Fd),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard),
      initialStrategyId: StrategyId.wrap(12)
    });
  }
}
