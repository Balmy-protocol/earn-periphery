// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
  IEarnStrategyRegistry, EarnStrategyRegistry
} from "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";
import { FirewalledEarnVault } from "@balmy/earn-core/vault/FirewalledEarnVault.sol";
import { EarnNFTDescriptor } from "@balmy/earn-core/nft-descriptor/EarnNFTDescriptor.sol";
import { FirewalledEarnVaultCompanion, IPermit2 } from "src/companion/FirewalledEarnVaultCompanion.sol";
import { ICreationValidationManagerCore } from "src/interfaces/ICreationValidationManager.sol";

import { GlobalEarnRegistry } from "src/global-registry/GlobalEarnRegistry.sol";
import { FeeManager, Fees } from "src/strategies/layers/fees/external/FeeManager.sol";
import { GuardianManager } from "src/strategies/layers/guardian/external/GuardianManager.sol";
import { LiquidityMiningManager } from "src/strategies/layers/liquidity-mining/external/LiquidityMiningManager.sol";
import { DelayedWithdrawalManager } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import { TOSManager } from "src/strategies/layers/creation-validation/external/TOSManager.sol";
import { GlobalValidationManagersRegistry } from
  "src/strategies/layers/creation-validation/external/GlobalValidationManagersRegistry.sol";
import { SignatureBasedWhitelistManager } from
  "src/strategies/layers/creation-validation/external/SignatureBasedWhitelistManager.sol";
import { ExternalFirewall } from "@forta/firewall/ExternalFirewall.sol";
import {
  FirewallAccess,
  FIREWALL_ADMIN_ROLE,
  PROTOCOL_ADMIN_ROLE,
  ATTESTER_MANAGER_ROLE,
  CHECKPOINT_EXECUTOR_ROLE,
  TRUSTED_ATTESTER_ROLE
} from "@forta/firewall/FirewallAccess.sol";
import { ISecurityValidator } from "@forta/firewall/SecurityValidator.sol";
import { FirewallRouter } from "@forta/firewall/FirewallRouter.sol";

import { ICheckpointHook } from "@forta/firewall/interfaces/ICheckpointHook.sol";
import { Checkpoint, Activation } from "@forta/firewall/interfaces/Checkpoint.sol";

import { BaseDeploy } from "./BaseDeploy.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployVault is BaseDeploy {
  function run() external {
    address signer = vm.envAddress("SIGNER");
    vm.startBroadcast(deployerPrivateKey);
    address strategyRegistry =
      deployContract("V1_STRATEGY_REGISTRY", abi.encodePacked(type(EarnStrategyRegistry).creationCode));
    console2.log("Strategy registry:", strategyRegistry);
    address nftDescriptor = deployContract(
      "V1_NFT_DESCRIPTOR",
      abi.encodePacked(
        type(EarnNFTDescriptor).creationCode, abi.encode("https://api.balmy.xyz/v1/earn/metadata/", admin)
      )
    );
    console2.log("NFT descriptor:", nftDescriptor);
    address[] memory initialAdmins = new address[](2);
    initialAdmins[0] = admin;
    initialAdmins[1] = deployer; // TODO: remove this

    // FORTA
    bytes32 attesterControllerId = bytes32("3");
    ISecurityValidator validator = ISecurityValidator(0xc9b1AeD0895Dd647A82e35Cafff421B6CcFe690C);

    address firewallAccess =
      deployContract("V1_FACCESS", abi.encodePacked(type(FirewallAccess).creationCode, abi.encode(deployer)));
    address externalFirewall = deployContract(
      "V1_FEXTERNAL",
      abi.encodePacked(
        type(ExternalFirewall).creationCode,
        abi.encode(validator, ICheckpointHook(address(0)), attesterControllerId, firewallAccess)
      )
    );
    address firewallRouter = deployContract(
      "V1_FROUTER",
      abi.encodePacked(
        type(FirewallRouter).creationCode,
        abi.encode(ExternalFirewall(externalFirewall), FirewallAccess(firewallAccess))
      )
    );
    address vault = deployContract(
      "V1_VAULT",
      abi.encodePacked(
        type(FirewalledEarnVault).creationCode,
        abi.encode(IEarnStrategyRegistry(strategyRegistry), admin, initialAdmins, nftDescriptor, firewallRouter)
      )
    );
    address permit2Adapter = 0xED306e38BB930ec9646FF3D917B2e513a97530b1;
    address companion = deployContract(
      "V1_COMPANION",
      abi.encodePacked(
        type(FirewalledEarnVaultCompanion).creationCode,
        abi.encode(
          permit2Adapter, address(0), admin, IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3), firewallRouter
        )
      )
    );
    console2.log("Vault:", vault);
    console2.log("Companion:", companion);
    /// will renounce later below
    FirewallAccess(firewallAccess).grantRole(FIREWALL_ADMIN_ROLE, deployer);
    FirewallAccess(firewallAccess).grantRole(PROTOCOL_ADMIN_ROLE, deployer);
    FirewallAccess(firewallAccess).grantRole(ATTESTER_MANAGER_ROLE, deployer);

    /// let protected contract execute checkpoints on the external firewall
    FirewallAccess(firewallAccess).grantRole(CHECKPOINT_EXECUTOR_ROLE, address(vault));
    FirewallAccess(firewallAccess).grantRole(CHECKPOINT_EXECUTOR_ROLE, address(companion));
    FirewallAccess(firewallAccess).grantRole(CHECKPOINT_EXECUTOR_ROLE, address(firewallRouter));

    /// set the trusted attester:
    /// this will be necessary when "foo()" receives an attested call later.
    FirewallAccess(firewallAccess).grantRole(TRUSTED_ATTESTER_ROLE, deployer);

    Checkpoint memory checkpoint =
      Checkpoint({ threshold: 0, refStart: 4, refEnd: 36, activation: Activation.AlwaysActive, trustedOrigin: false });

    ExternalFirewall(externalFirewall).setCheckpoint(FirewalledEarnVault(payable(vault)).withdraw.selector, checkpoint);
    ExternalFirewall(externalFirewall).setCheckpoint(
      FirewalledEarnVault(payable(vault)).specialWithdraw.selector, checkpoint
    );

    ExternalFirewall(externalFirewall).setCheckpoint(
      FirewalledEarnVaultCompanion(payable(companion)).withdraw.selector, checkpoint
    );
    ExternalFirewall(externalFirewall).setCheckpoint(
      FirewalledEarnVaultCompanion(payable(companion)).specialWithdraw.selector, checkpoint
    );

    FirewallAccess(firewallAccess).renounceRole(TRUSTED_ATTESTER_ROLE, deployer);
    FirewallAccess(firewallAccess).renounceRole(FIREWALL_ADMIN_ROLE, deployer);
    FirewallAccess(firewallAccess).renounceRole(PROTOCOL_ADMIN_ROLE, deployer);
    FirewallAccess(firewallAccess).renounceRole(ATTESTER_MANAGER_ROLE, deployer);
    console2.log("Firewall access:", firewallAccess);
    TOSManager.InitialToS[] memory initialToS = new TOSManager.InitialToS[](1);
    initialToS[0] = TOSManager.InitialToS({
      // solhint-disable-next-line max-line-length
      tos: "By selecting a Guardian, you acknowledge and accept the terms and conditions outlined in our Earn service's Terms of Use available at https://app.balmy.xyz/terms_of_use.pdf, including those related to the accuracy of data provided by third-party oracles and the actions taken by the Guardian in response to potential threats. Please note: Balmy does not guarantee the accuracy, completeness, or reliability of information from third-party yield providers. The Guardian operates on a best-effort basis to protect your funds in the event of a hack, and actions taken by the Guardian may impact the performance of your investment. Rescue fees may apply if funds are saved. Timing and decisions regarding redepositing or relocating funds are made in good faith, and Balmy is not liable for any financial losses resulting from these actions. Each Guardian may have its own specific terms of service, which will be presented to you before you engage with their service. By selecting a Guardian and proceeding, you agree to those terms. By signing this I acknowledge and agree to the above terms and conditions.",
      group: TOS_GROUP
    });
    address tosManager = deployContract(
      "V1_TOS_MANAGER",
      abi.encodePacked(
        type(TOSManager).creationCode,
        abi.encode(strategyRegistry, admin, initialAdmins, initialToS, new TOSManager.InitialGroup[](0))
      )
    );

    address[] memory initialNoValidation = new address[](1);
    initialNoValidation[0] = companion;
    address[] memory initialNonceSpenders = new address[](2);
    initialNonceSpenders[0] = companion;
    initialNonceSpenders[1] = vault;
    address[] memory initialManagerSigners = new address[](3);
    initialManagerSigners[0] = signer;
    initialManagerSigners[1] = deployer;
    initialManagerSigners[2] = admin;

    SignatureBasedWhitelistManager.InitialSigner[] memory initialSigners =
      new SignatureBasedWhitelistManager.InitialSigner[](1);
    initialSigners[0] = SignatureBasedWhitelistManager.InitialSigner({ signer: signer, group: SIGNER_GROUP });
    address signatureBasedWhitelistManager = deployContract(
      "V1_SIGNATURE",
      abi.encodePacked(
        type(SignatureBasedWhitelistManager).creationCode,
        abi.encode(
          strategyRegistry,
          admin,
          initialNoValidation,
          initialNonceSpenders,
          initialManagerSigners,
          initialSigners,
          new SignatureBasedWhitelistManager.InitialGroup[](0)
        )
      )
    );

    ICreationValidationManagerCore[] memory managers = new ICreationValidationManagerCore[](2);
    managers[0] = ICreationValidationManagerCore(tosManager);
    managers[1] = ICreationValidationManagerCore(signatureBasedWhitelistManager);
    address validationManagersRegistry = deployContract(
      "V1_VALIDATION_MANAGERS_REGISTRY",
      abi.encodePacked(type(GlobalValidationManagersRegistry).creationCode, abi.encode(managers, admin))
    );

    address feeManager = deployContract(
      "V1_FEE_MANAGER",
      abi.encodePacked(
        type(FeeManager).creationCode, abi.encode(admin, initialAdmins, initialAdmins, Fees(0, 0, 500, 1000))
      )
    );
    address guardianManager = deployContract(
      "V1_GUARDIAN_MANAGER",
      abi.encodePacked(
        type(GuardianManager).creationCode,
        abi.encode(strategyRegistry, admin, initialAdmins, initialAdmins, initialAdmins, initialAdmins)
      )
    );
    address delayedWithdrawalManager = deployContract(
      "V1_DELAYED_WITHDRAWAL_MANAGER", abi.encodePacked(type(DelayedWithdrawalManager).creationCode, abi.encode(vault))
    );
    address liquidityMiningManager = deployContract(
      "V1_LIQUIDITY_MINING_MANAGER",
      abi.encodePacked(type(LiquidityMiningManager).creationCode, abi.encode(strategyRegistry, admin, initialAdmins))
    );

    GlobalEarnRegistry.InitialConfig[] memory config = new GlobalEarnRegistry.InitialConfig[](5);
    config[0] = GlobalEarnRegistry.InitialConfig({ id: keccak256("FEE_MANAGER"), contractAddress: feeManager });
    config[1] =
      GlobalEarnRegistry.InitialConfig({ id: keccak256("GUARDIAN_MANAGER"), contractAddress: guardianManager });
    config[2] = GlobalEarnRegistry.InitialConfig({
      id: keccak256("LIQUIDITY_MINING_MANAGER"),
      contractAddress: liquidityMiningManager
    });
    config[3] = GlobalEarnRegistry.InitialConfig({
      id: keccak256("DELAYED_WITHDRAWAL_MANAGER"),
      contractAddress: delayedWithdrawalManager
    });
    config[4] = GlobalEarnRegistry.InitialConfig({
      id: keccak256("VALIDATION_MANAGERS_REGISTRY"),
      contractAddress: validationManagersRegistry
    });
    address globalRegistry = deployContract(
      "V1_GLOBAL_REGISTRY", abi.encodePacked(type(GlobalEarnRegistry).creationCode, abi.encode(config, admin))
    );
    console2.log("Global registry:", globalRegistry);

    vm.stopBroadcast();
  }
}
