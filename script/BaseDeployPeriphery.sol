// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployCore } from "@balmy/earn-core-script/BaseDeployCore.sol";

contract BaseDeployPeriphery is BaseDeployCore {
  address internal signer = vm.envAddress("SIGNER");

  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal SIGNER_GROUP = keccak256("signer_group");
  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal TOS_GROUP = keccak256("guardian_tos");
}
