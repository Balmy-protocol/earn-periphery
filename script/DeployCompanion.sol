// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "./BaseDeployPeriphery.sol";
import { FirewalledEarnVaultCompanion, IPermit2 } from "src/companion/FirewalledEarnVaultCompanion.sol";

import { console2 } from "forge-std/console2.sol";

contract DeployCompanion is BaseDeployPeriphery {
  function run() external virtual {
    vm.startBroadcast();
    deployCompanion();
    vm.stopBroadcast();
  }

  function deployCompanion() public returns (address) {
    address firewallRouter = getDeployedAddress("V2_FROUTER");

    address companion = deployContract(
      "V2_COMPANION",
      abi.encodePacked(
        type(FirewalledEarnVaultCompanion).creationCode,
        abi.encode(
          permit2Adapter(), address(0), admin, IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3), firewallRouter
        )
      )
    );
    console2.log("Companion:", companion);
    return companion;
  }
}

function permit2Adapter() view returns (address) {
  if (
    block.chainid == 8453 // base
      || block.chainid == 1 // mainnet
      || block.chainid == 10 // optimism
      || block.chainid == 137 // polygon
      || block.chainid == 34_443 // mode
      || block.chainid == 42_161 // arbitrum
  ) {
    return 0xED306e38BB930ec9646FF3D917B2e513a97530b1;
  }
  revert("Unsupported chain");
}
