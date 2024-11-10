// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { CheckpointExecutor } from "@forta/firewall/CheckpointExecutor.sol";
import { IExternalFirewall } from "@forta/firewall/interfaces/IExternalFirewall.sol";
import { IPermit2 } from "../interfaces/external/IPermit2.sol";
import { EarnVaultCompanion } from "./EarnVaultCompanion.sol";

contract FirewalledEarnVaultCompanion is EarnVaultCompanion, CheckpointExecutor {
  constructor(
    address swapper_,
    address allowanceTarget_,
    address owner_,
    IPermit2 permit2,
    IExternalFirewall externalFirewall
  )
    EarnVaultCompanion(swapper_, allowanceTarget_, owner_, permit2)
  {
    _setExternalFirewall(externalFirewall);
  }
}
