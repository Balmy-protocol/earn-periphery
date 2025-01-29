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
    address cometRewards = 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae;

    // USDC
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
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
