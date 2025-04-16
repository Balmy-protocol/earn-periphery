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
    address cometRewards = 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae;
    address[] memory emptyGuardians = new address[](0);
    address[] memory emptyJudges = new address[](0);

    // USDC
    deployCompoundV3StrategyWithId({
      cometRewards: cometRewards,
      cToken: ICERC20(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 usdc - ", guard),
      initialStrategyId: StrategyId.wrap(50)
    });

    // USDT
    deployCompoundV3StrategyWithId({
      cometRewards: cometRewards,
      cToken: ICERC20(0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 usdt - ", guard),
      initialStrategyId: StrategyId.wrap(51)
    });

    // WETH
    deployCompoundV3StrategyWithId({
      cometRewards: cometRewards,
      cToken: ICERC20(0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486),
      tosGroup: bytes32(0),
      signerGroup: bytes32(0),
      guardians: emptyGuardians,
      judges: emptyJudges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 weth - ", guard),
      initialStrategyId: StrategyId.wrap(52)
    });
  }
}
