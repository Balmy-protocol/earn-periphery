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
      guard: ""
    });
    _deployCompoundV3Strategies({
      guardians: _getGuardiansArray(HYPERNATIVE_GUARDIAN, false),
      judges: judges,
      tosGroup: HYPERNATIVE_GUARDIAN_TOS_GROUP,
      guard: "hypernative"
    });
    vm.stopBroadcast();
  }

  function _deployCompoundV3Strategies(
    address[] memory guardians,
    address[] memory judges,
    bytes32 tosGroup,
    string memory guard
  )
    internal
  {
    address cometRewards = 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae;

    // USDC
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat("v1-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard)
    });

    // USDT
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat("v1-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard)
    });

    // WETH
    deployCompoundV3Strategy({
      cometRewards: cometRewards,
      cToken: ICERC20(0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat("v1-t0", guard))),
      description: string.concat("strategy tier 0 - ", guard)
    });
  }
}
