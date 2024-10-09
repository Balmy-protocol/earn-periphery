// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@balmy/earn-core/strategy-registry/EarnStrategyRegistry.sol";
import "@balmy/earn-core/vault/EarnVault.sol";
import "@balmy/earn-core/nft-descriptor/EarnNFTDescriptor.sol";

import "src/global-registry/GlobalEarnRegistry.sol";
import "src/fee-manager/FeeManager.sol";
import "src/guardian-manager/GuardianManager.sol";
import "src/liquidity-mining-manager/LiquidityMiningManager.sol";
import "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";
import "src/tos-manager/TOSManager.sol";

import "src/strategies/instances/erc4626/ERC4626Strategy.sol";
import "src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";

import "src/strategies/instances/aave-v3/AaveV3Strategy.sol";
import "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";


contract DeployPolygon is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = 0xB86dA339B88D9697fa3ACC55EDd378e002676E01;
    address admin = vm.envAddress("GOVERNOR");
    vm.startBroadcast(deployerPrivateKey);

    EarnStrategyRegistry strategyRegistry = new EarnStrategyRegistry();
    EarnNFTDescriptor nftDescriptor = EarnNFTDescriptor(0xAe84114Aa7a651F765B24c74f3A0f8E64921C3D9);
    address[] memory initialAdmins = new address[](2);
    initialAdmins[0] = admin;
    initialAdmins[1] = deployer;
    EarnVault vault = new EarnVault(strategyRegistry, admin, initialAdmins, nftDescriptor);

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
    erc4626Factory.cloneAndRegister(
      strategyRegistry,
      admin,
      vault,
      globalRegistry,
      IERC4626(0x90b2f54C6aDDAD41b8f6c4fCCd555197BC0F773B), // Yearn v3 DAI-A
      "",
      "",
      "",
      ""
    );

    (, StrategyId strategyIdWETH) = erc4626Factory.cloneAndRegister(
      strategyRegistry,
      admin,
      vault,
      globalRegistry,
      IERC4626(0x305F25377d0a39091e99B975558b1bdfC3975654), // Yearn v3 WETH-A
      "",
      "",
      "",
      ""
    );

    // Needs DAI to create the campaign
    /*
    liquidityMiningManager.setCampaign(
      strategyIdWETH, 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, 1, block.timestamp + 10
    );
    */

    AaveV3Strategy aaveV3 = new AaveV3Strategy();
    AaveV3StrategyFactory aaveV3Factory = new AaveV3StrategyFactory(aaveV3);
    aaveV3Factory.cloneAndRegister(
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
    vm.stopBroadcast();
  }
}
