import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { ERC4626DelayedStrategy } from "src/strategies/instances/erc4626/ERC4626DelayedStrategy.sol";
import { FirewalledEarnVault } from "@balmy/earn-core/vault/FirewalledEarnVault.sol";
import {
  StrategyId,
  IEarnVault,
  INFTPermissions,
  IEarnStrategy,
  SpecialWithdrawalCode
} from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { SpecialWithdrawalCode } from "@balmy/earn-core/types/SpecialWithdrawals.sol";
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

import "src/strategies/instances/erc4626/ERC4626DelayedStrategy.sol";
import "src/strategies/layers/connector/lido/ERC4626DelayedWithdrawalAdapter.sol";

import "src/strategies/instances/aave-v3/AaveV3Strategy.sol";
import "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";

import "@forta/firewall/ExternalFirewall.sol";
import "@forta/firewall/FirewallAccess.sol";
import "@forta/firewall/SecurityValidator.sol";
import "@forta/firewall/FirewallRouter.sol";

import "@forta/firewall/interfaces/ICheckpointHook.sol";
import "@forta/firewall/interfaces/Checkpoint.sol";

contract ERC4626DelayedStrategyTest is PRBTest, StdUtils, StdCheats {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("polygon"));
  }

  function test_withdraw_strategy() public {
    ERC4626DelayedStrategy strategy = ERC4626DelayedStrategy(payable(0x98FFd2CdB5B6c653e680c22Ef13d7a195dB48ff3));
    address[] memory tokens = new address[](2);
    tokens[0] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    uint256[] memory toWithdraw = new uint256[](1);
    toWithdraw[0] = 5_000_000;

    vm.prank(0x58E5d76Fbbd7E1b51F0fC0F66B7734E108be0461);
    strategy.withdraw({ positionId: 2, tokens: tokens, toWithdraw: toWithdraw, recipient: address(this) });
  }

  function test_withdraw_vault() public {
    FirewalledEarnVault vault = FirewalledEarnVault(payable(0x58E5d76Fbbd7E1b51F0fC0F66B7734E108be0461));

    uint256[] memory toWithdraw = new uint256[](1);
    toWithdraw[0] = 5_000_000;
    vm.prank(0xB86dA339B88D9697fa3ACC55EDd378e002676E01);
    vault.specialWithdraw(2, SpecialWithdrawalCode.wrap(1), toWithdraw, "0x", address(this));
  }

  function test_withdraw_vault_2() public {
    address deployer = 0xB86dA339B88D9697fa3ACC55EDd378e002676E01;
    address admin = vm.envAddress("GOVERNOR");
    vm.startPrank(deployer);
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

   
    FeeManager feeManager = new FeeManager(admin, initialAdmins, initialAdmins, Fees(0, 0, 500, 1000));
    GuardianManager guardianManager =
      new GuardianManager(strategyRegistry, admin, initialAdmins, initialAdmins, initialAdmins, initialAdmins);
    DelayedWithdrawalManager delayedWithdrawalManager = new DelayedWithdrawalManager(vault);

    TOSManager tosManager = new TOSManager(strategyRegistry, admin, initialAdmins);

    // LiquidityMiningManager liquidityMiningManager = new LiquidityMiningManager(strategyRegistry, admin, initialAdmins);
    LiquidityMiningManager liquidityMiningManager = LiquidityMiningManager(0x64665eE43B54C1B08AE3198403462a2B7CC2c009);
    GlobalEarnRegistry globalRegistry = new GlobalEarnRegistry(deployer);
    globalRegistry.setAddress(keccak256("FEE_MANAGER"), address(feeManager));
    globalRegistry.setAddress(keccak256("GUARDIAN_MANAGER"), address(guardianManager));
    globalRegistry.setAddress(keccak256("LIQUIDITY_MINING_MANAGER"), address(liquidityMiningManager));
    globalRegistry.setAddress(keccak256("DELAYED_WITHDRAWAL_MANAGER"), address(delayedWithdrawalManager));
    globalRegistry.setAddress(keccak256("TOS_MANAGER"), address(tosManager));
    globalRegistry.transferOwnership(admin);

 

       ERC4626DelayedWithdrawalAdapter delayedWithdrawalAdapter = new ERC4626DelayedWithdrawalAdapter(
      globalRegistry,
      0x0fEFEe13864c431717f5B2678607b6ce532a170C, // Yearn USDT CompoundV3 Lender (ysUSDT)
      7200 // 7200 seconds are 2 hours
    );

    ERC4626DelayedStrategy delayedStrategy = new ERC4626DelayedStrategy(
      globalRegistry,
      vault,
      0x0fEFEe13864c431717f5B2678607b6ce532a170C,
      "Delayed Yearn USDT CompoundV3 Lender (ysUSDT)",
      delayedWithdrawalAdapter
    );

   StrategyId strategyId = vault.STRATEGY_REGISTRY().registerStrategy(deployer, delayedStrategy);
     liquidityMiningManager.setCampaign{ value: 0.00001 ether }(
      strategyId, Token.NATIVE_TOKEN, 0.000000000001 ether, 10_000_000
    );

    INFTPermissions.PermissionSet[] memory permissions = new INFTPermissions.PermissionSet[](1);
    deal(0xc2132D05D31c914a87C6611C10748AEb04B58e8F, deployer, 1000000);
    IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F).approve(address(vault), type(uint256).max);
    vault.createPosition({
      strategyId: delayedStrategy.strategyId(),
      depositToken: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
      depositAmount: 100,
      owner: deployer,
      permissions: permissions,
      strategyValidationData: "",
      misc: ""
    });

    vault.createPosition({
      strategyId: delayedStrategy.strategyId(),
      depositToken: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
      depositAmount: 100,
      owner: deployer,
      permissions: permissions,
      strategyValidationData: "",
      misc: ""
    });

    vault.createPosition({
      strategyId: delayedStrategy.strategyId(),
      depositToken: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
      depositAmount: 100,
      owner: deployer,
      permissions: permissions,
      strategyValidationData: "",
      misc: ""
    });

    vault.createPosition({
      strategyId: delayedStrategy.strategyId(),
      depositToken: 0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
      depositAmount: 100,
      owner: deployer,
      permissions: permissions,
      strategyValidationData: "",
      misc: ""
    });

   uint256[] memory toWithdraw = new uint256[](1);
    toWithdraw[0] = 10;
    vault.specialWithdraw(2, SpecialWithdrawalCode.wrap(1), toWithdraw, "0x", address(this));
    /*
    uint256[] memory toWithdraw = new uint256[](2);
    toWithdraw[0] = 10;
    toWithdraw[1] = type(uint256).max;
    address[] memory tokens = new address[](2);
    tokens[0] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    tokens[1] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    vault.withdraw(2, tokens, toWithdraw, address(this));
    */
  }
}
