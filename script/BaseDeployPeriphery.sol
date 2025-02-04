// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeploy } from "@balmy/earn-core-script/BaseDeploy.sol";
import { Fees } from "src/types/Fees.sol";

contract BaseDeployPeriphery is BaseDeploy {
  address internal signer = vm.envAddress("SIGNER");
  address internal relayer = vm.envAddress("RELAYER");

  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal DEFAULT_SIGNER_GROUP = keccak256("default_signer_group");
  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal BALMY_GUARDIAN_TOS_GROUP = keccak256("balmy_guardian_guardian_tos");
  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal HYPERNATIVE_GUARDIAN_TOS_GROUP = keccak256("hypernative_guardian_guardian_tos");

  // solhint-disable-next-line var-name-mixedcase
  address internal BALMY_GUARDIAN = 0x653c69a2dE94BeC3953C76c64763A1f1438207c6;
  // solhint-disable-next-line var-name-mixedcase
  address internal HYPERNATIVE_GUARDIAN = 0xbc0eBf2490E08F4a40444e976fCBF3aEF0e76c2A;

  // solhint-disable-next-line var-name-mixedcase
  Fees internal DEFAULT_FEES = Fees({
    depositFee: type(uint16).max,
    withdrawFee: type(uint16).max,
    performanceFee: type(uint16).max,
    rescueFee: type(uint16).max
  });

  function getGuardianArrayWithMsig(address guardian) internal view returns (address[] memory guardians) {
    guardians = new address[](2);
    guardians[0] = guardian;
    guardians[1] = getMsig();
    return guardians;
  }
}
