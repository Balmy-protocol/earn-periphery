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

import "src/strategies/instances/erc4626/ERC4626Strategy.sol";
import "src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";

import "src/strategies/instances/beefy/BeefyStrategy.sol";
import "src/strategies/instances/beefy/BeefyStrategyFactory.sol";

import "@forta/firewall/ExternalFirewall.sol";
import "@forta/firewall/FirewallAccess.sol";
import "@forta/firewall/SecurityValidator.sol";

contract DeployFortaPolygon is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = 0xB86dA339B88D9697fa3ACC55EDd378e002676E01;
    address admin = vm.envAddress("GOVERNOR");
    vm.startBroadcast(deployerPrivateKey);

    EarnStrategyRegistry strategyRegistry = new EarnStrategyRegistry();
    EarnNFTDescriptor nftDescriptor = new EarnNFTDescriptor();
    address[] memory initialAdmins = new address[](2);
    initialAdmins[0] = admin;
    initialAdmins[1] = deployer;

    // FORTA
    bytes32 attesterControllerId = bytes32("123");
    SecurityValidator validator = new SecurityValidator(address(this));
    FirewallAccess firewallAccess = new FirewallAccess(address(this));
    IExternalFirewall externalFirewall =
      new ExternalFirewall(validator, ICheckpointHook(address(0)), attesterControllerId, firewallAccess);
    FirewalledEarnVault vault =
      new FirewalledEarnVault(strategyRegistry, admin, initialAdmins, nftDescriptor, externalFirewall);

    FirewalledEarnVaultCompanion companion = new FirewalledEarnVaultCompanion(
      0xED306e38BB930ec9646FF3D917B2e513a97530b1,
      address(0),
      admin,
      IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3),
      externalFirewall
    );

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

    ERC4626Strategy erc4626 = new ERC4626Strategy();
    ERC4626StrategyFactory erc4626Factory = new ERC4626StrategyFactory(erc4626);

    /*
    - Morpho
        - Stablecoin
        - Reward: ETH
    */
    (,StrategyId strategyIdMorpho) = erc4626Factory.cloneAndRegister(
      vault.STRATEGY_REGISTRY(),
      admin,
      vault,
      globalRegistry,
      IERC4626(0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca), // Moonwell Flagship USDC
      "",
      "",
      "",
      ""
    );

    // Needs ETH to create the campaign
    
    liquidityMiningManager.setCampaign{value: 0.00001 ether}(
      strategyIdMorpho, Token.NATIVE_TOKEN, 0.000000000001 ether, 10000000
    );
    


    BeefyStrategy beefyStrategy = new BeefyStrategy();
    BeefyStrategyFactory beefyStrategyFactory = new BeefyStrategyFactory(beefyStrategy);
    /*
     - Beefy
        - WETH
        - TOS
    */
    (,StrategyId strategyIdBeefy) = beefyStrategyFactory.cloneAndRegister(
      vault.STRATEGY_REGISTRY(),
      admin,
      vault,
      globalRegistry,
      IBeefyVault(0x367A8DF45A165fD0A4405b4c45773d50E427322F), // WETH (superOETHb Market)
      0x4200000000000000000000000000000000000006, // WETH
      "",
      "",
      "",
      ""
    );

    bytes32 GROUP = keccak256("guardian_tos");
    tosManager.updateTOS(
      GROUP,
      "By selecting a Guardian, you acknowledge and accept the terms and conditions outlined in our Earn service's Terms of Use available at https://app.balmy.xyz/terms_of_use.pdf, including those related to the accuracy of data provided by third-party oracles and the actions taken by the Guardian in response to potential threats. Please note: Balmy does not guarantee the accuracy, completeness, or reliability of information from third-party yield providers. The Guardian operates on a best-effort basis to protect your funds in the event of a hack, and actions taken by the Guardian may impact the performance of your investment. Rescue fees may apply if funds are saved. Timing and decisions regarding redepositing or relocating funds are made in good faith, and Balmy is not liable for any financial losses resulting from these actions. Each Guardian may have its own specific terms of service, which will be presented to you before you engage with their service. By selecting a Guardian and proceeding, you agree to those terms. By signing this I acknowledge and agree to the above terms and conditions."
    );
    tosManager.assignStrategyToGroup(strategyIdBeefy, GROUP);
    vm.stopBroadcast();
  }
}
