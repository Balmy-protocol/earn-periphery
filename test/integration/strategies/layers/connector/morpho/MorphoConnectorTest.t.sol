// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {
  MorphoConnector,
  IGlobalEarnRegistry,
  IEarnStrategy,
  StrategyId
} from "src/strategies/layers/connector/morpho/MorphoConnector.sol";
import { GlobalEarnRegistry } from "src/global-registry/GlobalEarnRegistry.sol";
import { BaseConnectorInstance } from "../base/BaseConnectorTest.t.sol";
import { BaseConnectorImmediateWithdrawalTest } from "../base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest, SpecialWithdrawal } from "../base/BaseConnectorFarmTokenTest.t.sol";
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

  function testFork_allTokens_withRewards() public {
    _sendAndConfigureRewards(_MORPHO_TOKEN, 8640e10, 1 days);

    address[] memory tokens = connector.allTokens();
    assertEq(tokens, CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN));
  }

  function testFork_supportedWithdrawals_withRewards() public {
    _sendAndConfigureRewards(_MORPHO_TOKEN, 8640e10, 1 days);

    IEarnStrategy.WithdrawalType[] memory types = connector.supportedWithdrawals();
    assertEq(types.length, 2);
    assertTrue(types[0] == IEarnStrategy.WithdrawalType.IMMEDIATE);
    assertTrue(types[1] == IEarnStrategy.WithdrawalType.IMMEDIATE);
  }

  function testFork_totalBalances_withRewards() public {
    uint256 totalRewards = 8640e10;
    uint256 initialTimestamp = block.timestamp;
    _sendAndConfigureRewards(_MORPHO_TOKEN, totalRewards, 1 days);

    (address[] memory tokens, uint256[] memory balances) = connector.totalBalances();
    assertEq(tokens, CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN));
    assertEq(balances, CommonUtils.arrayOf(0, 0));

    vm.warp(initialTimestamp + 0.5 days);

    (tokens, balances) = connector.totalBalances();
    assertEq(tokens, CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN));
    assertEq(balances, CommonUtils.arrayOf(0, totalRewards / 2));

    vm.warp(initialTimestamp + 1 days);

    (tokens, balances) = connector.totalBalances();
    assertEq(tokens, CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN));
    assertEq(balances, CommonUtils.arrayOf(0, totalRewards));
  }

  function testFork_maxWithdraw_withRewards() public {
    uint256 totalRewards = 8640e10;
    uint256 initialTimestamp = block.timestamp;
    _sendAndConfigureRewards(_MORPHO_TOKEN, totalRewards, 1 days);

    (address[] memory tokens, uint256[] memory withdrawable) = connector.maxWithdraw();
    assertEq(tokens, CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN));
    assertEq(withdrawable, CommonUtils.arrayOf(0, 0));

    vm.warp(initialTimestamp + 0.5 days);

    (tokens, withdrawable) = connector.maxWithdraw();
    assertEq(tokens, CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN));
    assertEq(withdrawable, CommonUtils.arrayOf(0, totalRewards / 2));

    vm.warp(initialTimestamp + 1 days);

    (tokens, withdrawable) = connector.maxWithdraw();
    assertEq(tokens, CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN));
    assertEq(withdrawable, CommonUtils.arrayOf(0, totalRewards));
  }

  function testFork_withdraw_withRewards() public {
    uint256 totalRewards = 8640e10;
    uint256 initialTimestamp = block.timestamp + 0;
    address depositToken = _GAUNTLET_DAI.asset();
    _sendAndConfigureRewards(_MORPHO_TOKEN, totalRewards, 1 days);

    _give(depositToken, address(this), 10e10);
    IERC20(depositToken).approve(address(connector), type(uint256).max);
    uint256 assetsDeposited = connector.deposit(depositToken, 10e10);

    vm.warp(initialTimestamp + 0.5 days);

    connector.withdraw(
      0,
      CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN),
      CommonUtils.arrayOf(assetsDeposited / 2, totalRewards / 4),
      address(this)
    );

    assertEq(IERC20(depositToken).balanceOf(address(this)), assetsDeposited / 2);
    assertEq(IERC20(_MORPHO_TOKEN).balanceOf(address(this)), totalRewards / 4);

    (, uint256[] memory balances) = connector.totalBalances();
    assertEq(balances.length, 2);
    assertGte(balances[0], assetsDeposited / 2);
    assertEq(balances[1], totalRewards / 4);

    vm.warp(initialTimestamp + 1 days);

    (, balances) = connector.totalBalances();
    assertEq(balances.length, 2);
    assertGte(balances[0], assetsDeposited / 2);
    assertEq(balances[1], totalRewards * 3 / 4);
  }

  function testFork_migration_withRewards() public {
    // Add rewards
    uint256 totalRewards = 8640e10;
    _sendAndConfigureRewards(_MORPHO_TOKEN, totalRewards, 1 days);

    // Add asset
    address depositToken = _GAUNTLET_DAI.asset();
    _give(depositToken, address(this), 10e10);
    IERC20(depositToken).approve(address(connector), type(uint256).max);
    uint256 assetsDeposited = connector.deposit(depositToken, 10e10);

    vm.warp(block.timestamp + 0.5 days);

    // Check balances before migration
    (, uint256[] memory oldBalances) = connector.totalBalances();
    assertGte(oldBalances[0], assetsDeposited);
    assertEq(oldBalances[1], totalRewards / 2);

    // Migrate
    MorphoConnectorInstance newConnector = new MorphoConnectorInstance(_GAUNTLET_DAI, registry);
    bytes memory migrationData = connector.migrateToNewStrategy(IEarnStrategy(address(newConnector)), "");
    newConnector.strategyRegistered(StrategyId.wrap(1), IEarnStrategy(address(connector)), migrationData);

    // Make sure balances were migrated correctly
    (address[] memory tokens, uint256[] memory balances) = newConnector.totalBalances();
    assertEq(tokens, CommonUtils.arrayOf(_GAUNTLET_DAI.asset(), _MORPHO_TOKEN));
    assertEq(balances, oldBalances);

    // Make sure full amount of rewards were migrated
    assertEq(IERC20(_MORPHO_TOKEN).balanceOf(address(newConnector)), totalRewards);

    // Make sure rewards configs were migrated correctly
    (uint88 emissionPerSecond, uint32 deadline, uint104 emittedBeforeLastUpdate, uint32 lastUpdated) =
      MorphoConnector(address(connector)).rewards(_MORPHO_TOKEN);
    (uint88 newEmissionPerSecond, uint32 newDeadline, uint104 newEmittedBeforeLastUpdate, uint32 newLastUpdated) =
      newConnector.rewards(_MORPHO_TOKEN);

    assertEq(newEmissionPerSecond, emissionPerSecond);
    assertEq(newDeadline, deadline);
    assertEq(newEmittedBeforeLastUpdate, emittedBeforeLastUpdate);
    assertEq(newLastUpdated, lastUpdated);
  }

  function testFork_specialWithdraw_withRewards() public {
    _sendAndConfigureRewards(_MORPHO_TOKEN, 8640e10, 1 days);
    address recipient = address(1);
    uint256 originalConnectorBalance = _connectorBalanceOfFarmToken();
    uint256 amountToWithdraw = _amountToWithdrawFarmToken();
    uint256[] memory toWithdraw = new uint256[](1);
    toWithdraw[0] = amountToWithdraw;
    _setBalance(_farmToken(), recipient, 0);
    _setBalance(_farmToken(), address(connector), originalConnectorBalance);

    (, uint256[] memory balancesBefore) = connector.totalBalances();

    (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    ) = connector.specialWithdraw(1, SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT, toWithdraw, "", recipient);

    (, uint256[] memory balancesAfter) = connector.totalBalances();

    // Check assets
    uint256 assetsWithdrawn = balanceChanges[0];
    assertEq(balanceChanges.length, balancesBefore.length);
    assertAlmostEq(assetsWithdrawn, balancesBefore[0] - balancesAfter[0], 2);

    // Check actual tokens and amounts
    assertEq(actualWithdrawnTokens.length, 1);
    assertEq(actualWithdrawnAmounts.length, 1);
    assertEq(actualWithdrawnTokens[0], _farmToken());
    assertEq(actualWithdrawnAmounts[0], amountToWithdraw);

    // Check result
    assertTrue(result.length == 0);

    // Check transfer
    assertAlmostEq(_balance(_farmToken(), recipient), amountToWithdraw, 2);
    assertAlmostEq(_balance(_farmToken(), address(connector)), originalConnectorBalance - amountToWithdraw, 2);
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
