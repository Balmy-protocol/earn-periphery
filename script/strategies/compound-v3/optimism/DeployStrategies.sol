// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, ICERC20 } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    address[] memory judges = new address[](1);
    judges[0] = getMsig();

    vm.startBroadcast();
    deployPeriphery();
    _deployCompoundV3Strategies({
      guardians: _getGuardiansArray(BALMY_GUARDIAN, true),
      judges: judges,
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      guard: "",
      version: "v3"
    });
    _deployCompoundV3Strategies({
      guardians: _getGuardiansArray(HYPERNATIVE_GUARDIAN, false),
      judges: judges,
      tosGroup: HYPERNATIVE_GUARDIAN_TOS_GROUP,
      guard: "hypernative",
      version: "v1"
    });

    vm.stopBroadcast();
  }

  function _deployCompoundV3Strategies(
    address[] memory guardians,
    address[] memory judges,
    bytes32 tosGroup,
    string memory guard,
    string memory version
  )
    internal
  {
    address cometRewards = 0x443EA0340cb75a160F31A440722dec7b5bc3C2E9;

    // USDC
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0x2e44e174f7D53F0212823acC11C01A11d58c5bCB),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard)
    });

    // USDT
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0x995E394b8B2437aC8Ce61Ee0bC610D617962B214),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard)
    });

    // WETH
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0xE36A30D249f7761327fd973001A32010b521b6Fd),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: keccak256(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard)
    });
  }
}
