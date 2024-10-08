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

import "src/strategies/instances/lido/LidoSTETHStrategy.sol";
import "src/delayed-withdrawal-adapter/LidoSTETHDelayedWithdrawalAdapter.sol";

contract DeployMainnet is Script {
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

    LidoSTETHStrategy strategy = new LidoSTETHStrategy(
      globalRegistry,
      vault,
      "Earn Balmy Lido STETH Strategy",
      new LidoSTETHDelayedWithdrawalAdapter(globalRegistry, ILidoSTETHQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1))
    );

    strategyRegistry.registerStrategy(admin, strategy);

    vm.stopBroadcast();
  }
}
