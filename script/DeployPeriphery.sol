// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { FirewalledEarnVault } from "@balmy/earn-core/vault/FirewalledEarnVault.sol";
import { FirewalledEarnVaultCompanion } from "src/companion/FirewalledEarnVaultCompanion.sol";
import { ExternalFirewall } from "@forta/firewall/ExternalFirewall.sol";
import {
  FirewallAccess,
  FIREWALL_ADMIN_ROLE,
  PROTOCOL_ADMIN_ROLE,
  CHECKPOINT_EXECUTOR_ROLE
} from "@forta/firewall/FirewallAccess.sol";
import { Checkpoint, Activation } from "@forta/firewall/interfaces/Checkpoint.sol";

import { BaseDeployPeriphery } from "./BaseDeployPeriphery.sol";
import { DeployManagers } from "./DeployManagers.sol";
import { DeployCompanion } from "./DeployCompanion.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployPeriphery is BaseDeployPeriphery, DeployManagers, DeployCompanion {
  function run() external override(DeployManagers, DeployCompanion) {
    vm.startBroadcast();

    deployCompanion();
    configureCheckpoints();
    deployManagers();

    vm.stopBroadcast();
  }

  function configureCheckpoints() private {
    address firewallRouter = getDeployedAddress("V1_FIREWALL_ROUTER");
    FirewallAccess firewallAccess = FirewallAccess(getDeployedAddress("V1_FIREWALL_ACCESS"));
    ExternalFirewall externalFirewall = ExternalFirewall(getDeployedAddress("V1_EXTERNAL_FIREWALL"));
    address vault = getDeployedAddress("V1_VAULT");
    address companion = getDeployedAddress("V1_COMPANION");

    /// will renounce later below
    firewallAccess.grantRole(FIREWALL_ADMIN_ROLE, msg.sender);
    firewallAccess.grantRole(PROTOCOL_ADMIN_ROLE, msg.sender);

    /// let protected contract execute checkpoints on the external firewall
    firewallAccess.grantRole(CHECKPOINT_EXECUTOR_ROLE, vault);
    firewallAccess.grantRole(CHECKPOINT_EXECUTOR_ROLE, companion);
    firewallAccess.grantRole(CHECKPOINT_EXECUTOR_ROLE, firewallRouter);

    Checkpoint memory checkpoint =
      Checkpoint({ threshold: 0, refStart: 4, refEnd: 36, activation: Activation.AlwaysActive, trustedOrigin: false });

    externalFirewall.setCheckpoint(FirewalledEarnVault(payable(vault)).withdraw.selector, checkpoint);
    externalFirewall.setCheckpoint(FirewalledEarnVault(payable(vault)).specialWithdraw.selector, checkpoint);

    externalFirewall.setCheckpoint(FirewalledEarnVaultCompanion(payable(companion)).withdraw.selector, checkpoint);
    (externalFirewall).setCheckpoint(
      FirewalledEarnVaultCompanion(payable(companion)).specialWithdraw.selector, checkpoint
    );

    firewallAccess.renounceRole(FIREWALL_ADMIN_ROLE, msg.sender);
    firewallAccess.renounceRole(PROTOCOL_ADMIN_ROLE, msg.sender);
    console2.log("Firewall access:", address(firewallAccess));
  }
}
