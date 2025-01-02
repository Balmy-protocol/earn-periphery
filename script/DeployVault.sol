// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";
import "@balmy/earn-core/vault/FirewalledEarnVault.sol";
import "@balmy/earn-core/nft-descriptor/EarnNFTDescriptor.sol";
import "src/companion/FirewalledEarnVaultCompanion.sol";

import "src/global-registry/GlobalEarnRegistry.sol";
import "src/strategies/layers/fees/external/FeeManager.sol";
import "src/strategies/layers/guardian/external/GuardianManager.sol";
import "src/strategies/layers/liquidity-mining/external/LiquidityMiningManager.sol";
import "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import "src/strategies/layers/creation-validation/external/TOSManager.sol";
import "src/strategies/layers/creation-validation/external/GlobalValidationManagersRegistry.sol";
import "src/strategies/layers/creation-validation/external/SignatureBasedWhitelistManager.sol";
import "@forta/firewall/ExternalFirewall.sol";
import "@forta/firewall/FirewallAccess.sol";
import "@forta/firewall/SecurityValidator.sol";
import "@forta/firewall/FirewallRouter.sol";

import "@forta/firewall/interfaces/ICheckpointHook.sol";
import "@forta/firewall/interfaces/Checkpoint.sol";

import "src/strategies/instances/aave-v3/AaveV3Strategy.sol";
import "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";

import "src/strategies/instances/erc4626/ERC4626Strategy.sol";
import "src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";

import "src/strategies/instances/lido/LidoSTETHStrategy.sol";
import "src/strategies/instances/lido/LidoSTETHStrategyFactory.sol";

import "./BaseDeploy.sol";

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
        type(EarnNFTDescriptor).creationCode, abi.encode("http://api.balmy.xyz/v1/earn/metadata/", admin)
      )
    );
    console2.log("NFT descriptor:", nftDescriptor);
    address[] memory initialAdmins = new address[](2);
    initialAdmins[0] = admin;
    initialAdmins[1] = deployer;

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
    address tosManager = deployContract(
      "V1_TOS_MANAGER",
      abi.encodePacked(type(TOSManager).creationCode, abi.encode(strategyRegistry, admin, initialAdmins))
    );
    bytes32 GROUP = keccak256("guardian_tos");
    TOSManager(tosManager).updateTOS(
      GROUP,
      // solhint-disable-next-line max-line-length
      "By selecting a Guardian, you acknowledge and accept the terms and conditions outlined in our Earn service's Terms of Use available at https://app.balmy.xyz/terms_of_use.pdf, including those related to the accuracy of data provided by third-party oracles and the actions taken by the Guardian in response to potential threats. Please note: Balmy does not guarantee the accuracy, completeness, or reliability of information from third-party yield providers. The Guardian operates on a best-effort basis to protect your funds in the event of a hack, and actions taken by the Guardian may impact the performance of your investment. Rescue fees may apply if funds are saved. Timing and decisions regarding redepositing or relocating funds are made in good faith, and Balmy is not liable for any financial losses resulting from these actions. Each Guardian may have its own specific terms of service, which will be presented to you before you engage with their service. By selecting a Guardian and proceeding, you agree to those terms. By signing this I acknowledge and agree to the above terms and conditions."
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
    address signatureBasedWhitelistManager = deployContract(
      "V1_SIGNATURE",
      abi.encodePacked(
        type(SignatureBasedWhitelistManager).creationCode,
        abi.encode(strategyRegistry, admin, initialNoValidation, initialNonceSpenders, initialManagerSigners)
      )
    );

    bytes32 SIGNER_GROUP = keccak256("signer_group");
    SignatureBasedWhitelistManager(signatureBasedWhitelistManager).updateSigner(SIGNER_GROUP, signer);
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
