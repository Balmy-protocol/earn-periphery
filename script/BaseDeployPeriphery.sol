// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeploy } from "@balmy/earn-core-script/BaseDeploy.sol";

contract BaseDeployPeriphery is BaseDeploy {
  address internal signer = vm.envAddress("SIGNER");

  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal DEFAULT_SIGNER_GROUP = keccak256("default_signer_group");
  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal BALMY_GUARDIAN_TOS_GROUP = keccak256("balmy_guardian_guardian_tos");
}
