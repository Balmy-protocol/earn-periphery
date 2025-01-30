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
    address cometRewards = 0x443EA0340cb75a160F31A440722dec7b5bc3C2E9;

    // USDC
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0x2e44e174f7D53F0212823acC11C01A11d58c5bCB),
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
      cToken: ICERC20(0x995E394b8B2437aC8Ce61Ee0bC610D617962B214),
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
      cToken: ICERC20(0xE36A30D249f7761327fd973001A32010b521b6Fd),
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
