// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployStrategies, IERC4626 } from "../BaseDeployStrategies.sol";
import { DeployPeriphery } from "script/DeployPeriphery.sol";

contract DeployStrategies is DeployPeriphery, BaseDeployStrategies {
  function run() external override(DeployPeriphery) {
    address[] memory judges = new address[](1);
    address msig = getMsig();
    judges[0] = msig;

    vm.startBroadcast();
    deployPeriphery();
    _deployERC4626Strategies({
      guardians: _getGuardiansArray(BALMY_GUARDIAN, true),
      judges: judges,
      tosGroup: BALMY_GUARDIAN_TOS_GROUP,
      guard: "",
      version: "v1"
    });
    vm.stopBroadcast();
  }

  function _deployERC4626Strategies(
    address[] memory guardians,
    address[] memory judges,
    bytes32 tosGroup,
    string memory guard,
    string memory version
  )
    internal
  {
    // sDAI
    deployERC4626Strategy({
      erc4626Vault: IERC4626(0xaf204776c7245bF4147c2612BF6e5972Ee483701),
      tosGroup: tosGroup,
      signerGroup: bytes32(0),
      guardians: guardians,
      judges: judges,
      fees: DEFAULT_FEES,
      guard: bytes32(bytes(string.concat(version, "-t0", guard))),
      description: string.concat("strategy tier 0 - sDAI - ", guard)
    });
  }
}
