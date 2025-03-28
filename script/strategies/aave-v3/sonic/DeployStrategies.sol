// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IAToken } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    address[] memory judges = new address[](1);
    address msig = getMsig();
    judges[0] = msig;

    vm.startBroadcast();
    deployPeriphery();
    _deployAaveV3Strategies({
      guardians: _getGuardiansArray(BALMY_GUARDIAN, true),
      judges: judges,
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      guard: "",
      version: "v1"
    });

    vm.stopBroadcast();
  }

  function _deployAaveV3Strategies(
    address[] memory guardians,
    address[] memory judges,
    bytes32 tosGroup,
    string memory guard,
    string memory version
  )
    internal
  {
    address aaveV3Pool = 0x5362dBb1e601abF3a4c14c22ffEdA64042E5eAA3;
    address aaveV3Rewards = 0x24bD6e9ca54F1737467DEf82dCA9702925B3Aa59;

    // WETH
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0xe18Ab82c81E7Eecff32B8A82B1b7d2d23F1EcE96),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - weth - ", guard)
    });

    // USDC.e
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x578Ee1ca3a8E1b54554Da1Bf7C583506C4CD11c6),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - usdc.e - ", guard)
    });

    // WS
    deployAaveV3Strategy({
      aaveV3Pool: aaveV3Pool,
      aaveV3Rewards: aaveV3Rewards,
      aToken: IAToken(0x6C5E14A212c1C3e4Baf6f871ac9B1a969918c131),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - ws - ", guard)
    });
  }
}
