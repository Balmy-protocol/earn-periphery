// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { MorphoConnector, IGlobalEarnRegistry } from "src/strategies/layers/connector/morpho/MorphoConnector.sol";
import { GlobalEarnRegistry } from "src/global-registry/GlobalEarnRegistry.sol";
import { BaseConnectorInstance } from "../base/BaseConnectorTest.t.sol";
import { BaseConnectorImmediateWithdrawalTest } from "../base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "../base/BaseConnectorFarmTokenTest.t.sol";
import { CommonUtils } from "test/utils/CommonUtils.sol";

contract MorphoConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  // solhint-disable-next-line const-name-snakecase
  IERC4626 internal constant _GAUNTLET_DAI = IERC4626(0x500331c9fF24D9d11aee6B07734Aa72343EA74a5);
  address internal constant _MORPHO_TOKEN = 0x58D97B57BB95320F9a05dC918Aef65434969c2B2;
  GlobalEarnRegistry private registry;

  function _setUp() internal override {
    GlobalEarnRegistry.InitialConfig[] memory config = new GlobalEarnRegistry.InitialConfig[](1);
    // We are making ourselves the rewards manager, so that we can configure rewards
    config[0] =
      GlobalEarnRegistry.InitialConfig({ id: keccak256("MORPHO_REWARDS_MANAGER"), contractAddress: address(this) });
    registry = new GlobalEarnRegistry(config, address(this));
  }

  function _configureFork() internal override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);
    vm.rollFork(21_500_000);
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new MorphoConnectorInstance(_GAUNTLET_DAI, registry);
  }

  function _farmToken() internal pure override returns (address) {
    return address(_GAUNTLET_DAI);
  }

  function testFork_configureRewards_RevertWhen_CalledByNonManager() public {
    vm.prank(address(0));
    vm.expectRevert(abi.encodeWithSelector(MorphoConnector.OnlyManagerCanConfigureRewards.selector));
    MorphoConnectorInstance(address(connector)).configureRewards(CommonUtils.arrayOf(_MORPHO_TOKEN), 1 days);
  }

  function testFork_configureRewards_RevertWhen_TokenIsAsset() public {
    address asset = _GAUNTLET_DAI.asset();
    _give(asset, address(connector), 10e10);
    vm.expectRevert(abi.encodeWithSelector(MorphoConnector.RewardTokenCannotBeAsset.selector));
    MorphoConnectorInstance(address(connector)).configureRewards(CommonUtils.arrayOf(asset), 1 days);
  }

  function testFork_configureRewards() public {
    _sendAndConfigureRewards(_MORPHO_TOKEN, 8640e10, 1 days);
    (uint88 emissionPerSecond, uint32 deadline, uint104 emittedBeforeLastUpdate, uint32 lastUpdated) =
      MorphoConnectorInstance(address(connector)).rewards(_MORPHO_TOKEN);
    assertEq(emissionPerSecond, 8640e10 / 1 days);
    assertEq(deadline, block.timestamp + 1 days);
    assertEq(emittedBeforeLastUpdate, 0);
    assertEq(lastUpdated, block.timestamp);
  }

  function testFork_configureRewards_AlreadyConfiguredRewardToken() public {
    _sendAndConfigureRewards(_MORPHO_TOKEN, 8640e10, 1 days);
    // We just make sure nothing reverts
    _sendAndConfigureRewards(_MORPHO_TOKEN, 8640e10, 1 days);
  }

  function _sendAndConfigureRewards(address token, uint256 amount, uint256 duration) internal {
    _give(token, address(connector), amount);
    MorphoConnectorInstance(address(connector)).configureRewards(CommonUtils.arrayOf(token), duration);
  }
}

contract MorphoConnectorInstance is BaseConnectorInstance, MorphoConnector {
  IERC4626 internal immutable _vault;
  IGlobalEarnRegistry internal immutable _registry;

  constructor(IERC4626 vault_, IGlobalEarnRegistry registry_) initializer {
    _vault = vault_;
    _registry = registry_;
    _connector_init();
  }

  function ERC4626Vault() public view override returns (IERC4626) {
    return _vault;
  }

  function _asset() internal view override returns (IERC20) {
    return IERC20(_vault.asset());
  }

  function globalRegistry() public view override returns (IGlobalEarnRegistry) {
    return _registry;
  }
}
