// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@balmy/earn-core/vault/EarnVault.sol";
import "src/global-registry/GlobalEarnRegistry.sol";

import "src/strategies/instances/erc4626/ERC4626DelayedStrategy.sol";
import "src/delayed-withdrawal-adapter/ERC4626DelayedWithdrawalAdapter.sol";

contract DeployDummyDelayedStrategy is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = 0xB86dA339B88D9697fa3ACC55EDd378e002676E01;
    address admin = vm.envAddress("GOVERNOR");
    vm.startBroadcast(deployerPrivateKey);

    IEarnVault vault = IEarnVault(0x63a8aE714568EC8f8Ec14472674c68582b0B0458);
    IGlobalEarnRegistry globalRegistry = IGlobalEarnRegistry(0x7DA14784E8F1fb71c23Ad6c6ac7f063Fdf098F38);

    ERC4626DelayedWithdrawalAdapter delayedWithdrawalAdapter = new ERC4626DelayedWithdrawalAdapter(
      globalRegistry,
      0xBb287E6017d3DEb0e2E65061e8684eab21060123, // Yearn v3 USDT-A
      7200 // 7200 seconds are 2 hours
    );
    ERC4626DelayedStrategy delayedStrategy = new ERC4626DelayedStrategy(
      globalRegistry,
      vault,
      0xBb287E6017d3DEb0e2E65061e8684eab21060123,
      "Delayed Yearn v3 USDT-A",
      delayedWithdrawalAdapter
    );

    vault.STRATEGY_REGISTRY().registerStrategy(deployer, delayedStrategy);
    vm.stopBroadcast();
  }
}
