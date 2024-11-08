// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";
import "@balmy/earn-core/vault/FirewalledEarnVault.sol";
import "@balmy/earn-core/nft-descriptor/EarnNFTDescriptor.sol";
import "src/companion/FirewalledEarnVaultCompanion.sol";

import "src/global-registry/GlobalEarnRegistry.sol";
import "src/fee-manager/FeeManager.sol";
import "src/guardian-manager/GuardianManager.sol";
import "src/liquidity-mining-manager/LiquidityMiningManager.sol";
import "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import "src/tos-manager/TOSManager.sol";

import "src/strategies/instances/erc4626/ERC4626DelayedStrategy.sol";
import "src/delayed-withdrawal-adapter/ERC4626DelayedWithdrawalAdapter.sol";

import "src/strategies/instances/aave-v3/AaveV3Strategy.sol";
import "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";

import "@forta/firewall/ExternalFirewall.sol";
import "@forta/firewall/FirewallAccess.sol";
import "@forta/firewall/SecurityValidator.sol";
import "@forta/firewall/FirewallRouter.sol";

import "@forta/firewall/interfaces/ICheckpointHook.sol";
import  "@forta/firewall/interfaces/Checkpoint.sol";

contract DeployFortaPolygon is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = 0xB86dA339B88D9697fa3ACC55EDd378e002676E01;
    address admin = vm.envAddress("GOVERNOR");
    vm.startBroadcast(deployerPrivateKey);

    EarnStrategyRegistry strategyRegistry = new EarnStrategyRegistry();
    EarnNFTDescriptor nftDescriptor = EarnNFTDescriptor(0xAe84114Aa7a651F765B24c74f3A0f8E64921C3D9); // Recycle NFT
      // descriptor
    address[] memory initialAdmins = new address[](2);
    initialAdmins[0] = admin;
    initialAdmins[1] = deployer;

    // FORTA
    bytes32 attesterControllerId = bytes32("9999");
    ISecurityValidator validator = ISecurityValidator(0xc9b1AeD0895Dd647A82e35Cafff421B6CcFe690C);
    FirewallAccess firewallAccess = new FirewallAccess(deployer);
    ExternalFirewall externalFirewall =
      new ExternalFirewall(validator, ICheckpointHook(address(0)), attesterControllerId, firewallAccess);

    FirewallRouter firewallRouter = new FirewallRouter(externalFirewall, firewallAccess);
    FirewalledEarnVault vault =
      new FirewalledEarnVault(strategyRegistry, admin, initialAdmins, nftDescriptor, firewallRouter);

    FirewalledEarnVaultCompanion companion = new FirewalledEarnVaultCompanion(
      0xED306e38BB930ec9646FF3D917B2e513a97530b1,
      address(0),
      admin,
      IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3),
      firewallRouter
    );

    /// will renounce later below
    firewallAccess.grantRole(FIREWALL_ADMIN_ROLE, deployer);
    firewallAccess.grantRole(PROTOCOL_ADMIN_ROLE, deployer);
    firewallAccess.grantRole(ATTESTER_MANAGER_ROLE, deployer);

    /// let protected contract execute checkpoints on the external firewall
    firewallAccess.grantRole(CHECKPOINT_EXECUTOR_ROLE, address(vault));
    firewallAccess.grantRole(CHECKPOINT_EXECUTOR_ROLE, address(companion));
    firewallAccess.grantRole(CHECKPOINT_EXECUTOR_ROLE, address(firewallRouter));

    /// set the trusted attester:
    /// this will be necessary when "foo()" receives an attested call later.
    firewallAccess.grantRole(TRUSTED_ATTESTER_ROLE, deployer);

    Checkpoint memory checkpoint =
      Checkpoint({ threshold: 0, refStart: 4, refEnd: 36, activation: Activation.AlwaysActive, trustedOrigin: false });

    externalFirewall.setCheckpoint(vault.withdraw.selector, checkpoint);
    externalFirewall.setCheckpoint(vault.specialWithdraw.selector, checkpoint);

    externalFirewall.setCheckpoint(companion.withdraw.selector, checkpoint);
    externalFirewall.setCheckpoint(companion.specialWithdraw.selector, checkpoint);
    FeeManager feeManager = new FeeManager(admin, initialAdmins, initialAdmins, Fees(0, 0, 500, 1000));
    GuardianManager guardianManager =
      new GuardianManager(strategyRegistry, admin, initialAdmins, initialAdmins, initialAdmins, initialAdmins);
    DelayedWithdrawalManager delayedWithdrawalManager = new DelayedWithdrawalManager(vault);

    TOSManager tosManager = new TOSManager(strategyRegistry, admin, initialAdmins);

    LiquidityMiningManager liquidityMiningManager = new LiquidityMiningManager(strategyRegistry, admin, initialAdmins);

    GlobalEarnRegistry globalRegistry = new GlobalEarnRegistry(deployer);
    globalRegistry.setAddress(keccak256("FEE_MANAGER"), address(feeManager));
    globalRegistry.setAddress(keccak256("GUARDIAN_MANAGER"), address(guardianManager));
    globalRegistry.setAddress(keccak256("LIQUIDITY_MINING_MANAGER"), address(liquidityMiningManager));
    globalRegistry.setAddress(keccak256("DELAYED_WITHDRAWAL_MANAGER"), address(delayedWithdrawalManager));
    globalRegistry.setAddress(keccak256("TOS_MANAGER"), address(tosManager));
    globalRegistry.transferOwnership(admin);

    /*
    - Yearn
        - WMATIC
        - Delayed withdraw
        - Rewards: Stablecoin
    */

    ERC4626DelayedWithdrawalAdapter delayedWithdrawalAdapter = new ERC4626DelayedWithdrawalAdapter(
      globalRegistry,
      0x28F53bA70E5c8ce8D03b1FaD41E9dF11Bb646c36, // Yearn v3 WMATIC-A
      7200 // 7200 seconds are 2 hours
    );

    ERC4626DelayedStrategy delayedStrategy = new ERC4626DelayedStrategy(
      globalRegistry,
      vault,
      0x28F53bA70E5c8ce8D03b1FaD41E9dF11Bb646c36,
      "Delayed Yearn v3 WMATIC-A",
      delayedWithdrawalAdapter
    );

    vault.STRATEGY_REGISTRY().registerStrategy(deployer, delayedStrategy);

    // Needs DAI to create the campaign
    /*
    liquidityMiningManager.setCampaign(
      delayedStrategy.strategyId(), 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, 1, 100000
    );
    
*/
    /*
    - Aave v3
        - Stablecoin
        - TOS
    */
    AaveV3StrategyFactory aaveV3Factory = AaveV3StrategyFactory(0x5463cfE67361da69dffeBfB1e526de0d4bDCDE78); // Recycle
      // Aave v3 factory
    (, StrategyId strategyId) = aaveV3Factory.cloneAndRegister(
      AaveV3StrategyImmutableData(
        strategyRegistry,
        admin,
        vault,
        globalRegistry,
        IAToken(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE), // aDai
        IAaveV3Pool(0x794a61358D6845594F94dc1DB02A252b5b4814aD), // Aave v3 Pool
        IAaveV3Rewards(0x929EC64c34a17401F460460D4B9390518E5B473e), // Aave v3 Rewards
        "",
        "",
        "",
        ""
      )
    );

    bytes32 GROUP = keccak256("guardian_tos");
    tosManager.updateTOS(
      GROUP,
      "By selecting a Guardian, you acknowledge and accept the terms and conditions outlined in our Earn service's Terms of Use available at https://app.balmy.xyz/terms_of_use.pdf, including those related to the accuracy of data provided by third-party oracles and the actions taken by the Guardian in response to potential threats. Please note: Balmy does not guarantee the accuracy, completeness, or reliability of information from third-party yield providers. The Guardian operates on a best-effort basis to protect your funds in the event of a hack, and actions taken by the Guardian may impact the performance of your investment. Rescue fees may apply if funds are saved. Timing and decisions regarding redepositing or relocating funds are made in good faith, and Balmy is not liable for any financial losses resulting from these actions. Each Guardian may have its own specific terms of service, which will be presented to you before you engage with their service. By selecting a Guardian and proceeding, you agree to those terms. By signing this I acknowledge and agree to the above terms and conditions."
    );
    tosManager.assignStrategyToGroup(strategyId, GROUP);
    vm.stopBroadcast();
  }
}
