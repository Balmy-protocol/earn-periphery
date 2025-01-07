// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "./BaseDeployPeriphery.sol";

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

import { console2 } from "forge-std/console2.sol";

contract DeployManagers is BaseDeployPeriphery {
  function run() external virtual {
    vm.startBroadcast();
    deployManagers();
    vm.stopBroadcast();
  }

  function deployManagers() public {
    address vault = getDeployedAddress("V1_VAULT");
    address strategyRegistry = getDeployedAddress("V1_STRATEGY_REGISTRY");
    address companion = getDeployedAddress("V1_COMPANION");

    address[] memory initialAdmins = new address[](1);
    initialAdmins[0] = admin;

    TOSManager.InitialToS[] memory initialToS = new TOSManager.InitialToS[](1);
    initialToS[0] = TOSManager.InitialToS({
      // solhint-disable-next-line max-line-length
      tos: "By selecting a Guardian, you acknowledge and accept the terms and conditions outlined in our Earn service's Terms of Use available at https://app.balmy.xyz/terms_of_use.pdf, including those related to the accuracy of data provided by third-party oracles and the actions taken by the Guardian in response to potential threats. Please note: Balmy does not guarantee the accuracy, completeness, or reliability of information from third-party yield providers. The Guardian operates on a best-effort basis to protect your funds in the event of a hack, and actions taken by the Guardian may impact the performance of your investment. Rescue fees may apply if funds are saved. Timing and decisions regarding redepositing or relocating funds are made in good faith, and Balmy is not liable for any financial losses resulting from these actions. Each Guardian may have its own specific terms of service, which will be presented to you before you engage with their service. By selecting a Guardian and proceeding, you agree to those terms. By signing this I acknowledge and agree to the above terms and conditions.",
      group: BALMY_GUARDIAN_TOS_GROUP
    });
    address tosManager = deployContract(
      "V1_TOS_MANAGER",
      abi.encodePacked(
        type(TOSManager).creationCode,
        abi.encode(strategyRegistry, admin, initialAdmins, initialToS, new TOSManager.InitialGroup[](0))
      )
    );
    console2.log("TOS manager:", tosManager);

    address[] memory initialNoValidation = new address[](1);
    initialNoValidation[0] = companion;
    address[] memory initialNonceSpenders = new address[](2);
    initialNonceSpenders[0] = companion;
    initialNonceSpenders[1] = vault;
    address[] memory initialManagerSigners = new address[](1);
    initialManagerSigners[0] = signer;

    SignatureBasedWhitelistManager.InitialSigner[] memory initialSigners =
      new SignatureBasedWhitelistManager.InitialSigner[](1);
    initialSigners[0] = SignatureBasedWhitelistManager.InitialSigner({ signer: signer, group: DEFAULT_SIGNER_GROUP });
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
    console2.log("Signature based whitelist manager:", signatureBasedWhitelistManager);
    ICreationValidationManagerCore[] memory managers = new ICreationValidationManagerCore[](2);
    managers[0] = ICreationValidationManagerCore(tosManager);
    managers[1] = ICreationValidationManagerCore(signatureBasedWhitelistManager);
    address validationManagersRegistry = deployContract(
      "V1_VALIDATION_MANAGERS_REGISTRY",
      abi.encodePacked(type(GlobalValidationManagersRegistry).creationCode, abi.encode(managers, admin))
    );
    console2.log("Validation managers registry:", validationManagersRegistry);
    address feeManager = deployContract(
      "V1_FEE_MANAGER",
      abi.encodePacked(
        type(FeeManager).creationCode,
        abi.encode(
          strategyRegistry,
          admin,
          initialAdmins,
          initialAdmins,
          Fees({ depositFee: 0, withdrawFee: 0, performanceFee: 1000, rescueFee: 500 })
        )
      )
    );
    console2.log("Fee manager:", feeManager);
    address guardianManager = deployContract(
      "V1_GUARDIAN_MANAGER",
      abi.encodePacked(
        type(GuardianManager).creationCode,
        abi.encode(strategyRegistry, admin, new address[](0), initialAdmins, initialAdmins, initialAdmins)
      )
    );
    console2.log("Guardian manager:", guardianManager);
    address delayedWithdrawalManager = deployContract(
      "V1_DELAYED_WITHDRAWAL_MANAGER", abi.encodePacked(type(DelayedWithdrawalManager).creationCode, abi.encode(vault))
    );
    console2.log("Delayed withdrawal manager:", delayedWithdrawalManager);
    address liquidityMiningManager = deployContract(
      "V1_LIQUIDITY_MINING_MANAGER",
      abi.encodePacked(type(LiquidityMiningManager).creationCode, abi.encode(strategyRegistry, admin, initialAdmins))
    );
    console2.log("Liquidity mining manager:", liquidityMiningManager);

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
  }
}
