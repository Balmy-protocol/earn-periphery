// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import {
  IEarnStrategy,
  SpecialWithdrawalCode,
  StrategyId,
  IEarnVault,
  IEarnStrategyRegistry,
  IERC165
} from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IEarnBalmyStrategy } from "src/interfaces/IEarnBalmyStrategy.sol";
import { IDelayedWithdrawalAdapter } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";

import { LidoSTETHConnector } from "src/strategies/layers/connector/lido/LidoSTETHConnector.sol";

contract LidoSTETHStrategyMock is IEarnBalmyStrategy, LidoSTETHConnector {
  /// @inheritdoc IEarnStrategy
  IEarnVault public immutable vault;
  /// @inheritdoc IEarnStrategy
  string public description;

  // slither-disable-next-line naming-convention
  IDelayedWithdrawalAdapter internal immutable __delayedWithdrawalAdapter;

  constructor(
    // General
    IEarnVault vault_,
    string memory description_,
    IDelayedWithdrawalAdapter delayedWithdrawalAdapter_
  )
    initializer
  {
    vault = vault_;
    description = description_;
    __delayedWithdrawalAdapter = delayedWithdrawalAdapter_;
  }

  receive() external payable { }

  function registerStrategy(address owner) external returns (StrategyId) {
    return registry().registerStrategy(owner);
  }

  /// @inheritdoc IEarnStrategy
  function registry() public view returns (IEarnStrategyRegistry) {
    return vault.STRATEGY_REGISTRY();
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
    return interfaceId == type(IEarnBalmyStrategy).interfaceId || interfaceId == type(IEarnStrategy).interfaceId
      || interfaceId == type(IERC165).interfaceId;
  }

  /// @inheritdoc IEarnStrategy
  function asset() external pure returns (address) {
    return _connector_asset();
  }

  /// @inheritdoc IEarnStrategy
  function allTokens() external pure returns (address[] memory) {
    return _connector_allTokens();
  }

  /// @inheritdoc IEarnStrategy
  function isDepositTokenSupported(address depositToken) external view returns (bool) {
    return _connector_isDepositTokenSupported(depositToken);
  }

  /// @inheritdoc IEarnStrategy
  function supportedDepositTokens() external pure returns (address[] memory) {
    return _connector_supportedDepositTokens();
  }

  /// @inheritdoc IEarnStrategy
  function maxDeposit(address depositToken) external view returns (uint256) {
    return _connector_maxDeposit(depositToken);
  }

  /// @inheritdoc IEarnStrategy
  function supportedWithdrawals() external view returns (WithdrawalType[] memory) {
    return _connector_supportedWithdrawals();
  }

  /// @inheritdoc IEarnStrategy
  function isSpecialWithdrawalSupported(SpecialWithdrawalCode withdrawalCode) external pure returns (bool) {
    return _connector_isSpecialWithdrawalSupported(withdrawalCode);
  }

  /// @inheritdoc IEarnStrategy
  function supportedSpecialWithdrawals() external pure returns (SpecialWithdrawalCode[] memory) {
    return _connector_supportedSpecialWithdrawals();
  }

  /// @inheritdoc IEarnStrategy
  function maxWithdraw() external view returns (address[] memory, uint256[] memory) {
    return _connector_maxWithdraw();
  }

  /// @inheritdoc IEarnBalmyStrategy
  function delayedWithdrawalAdapter(address token) external view returns (IDelayedWithdrawalAdapter) {
    return _connector_delayedWithdrawalAdapter(token);
  }

  /// @inheritdoc IEarnStrategy
  function fees() external pure returns (IEarnStrategy.FeeType[] memory types, uint16[] memory bps) {
    types = new IEarnStrategy.FeeType[](0);
    bps = new uint16[](0);
  }

  function totalBalances() external view returns (address[] memory tokens, uint256[] memory balances) {
    return _connector_totalBalances();
  }

  /// @inheritdoc IEarnStrategy
  function deposited(address depositToken, uint256 depositAmount) external payable returns (uint256 assetsDeposited) {
    return _connector_deposit(depositToken, depositAmount);
  }

  /// @inheritdoc IEarnStrategy
  // solhint-disable-next-line no-empty-blocks
  function validatePositionCreation(address sender, bytes calldata creationData) external view { }

  /// @inheritdoc IEarnStrategy
  function withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    external
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return _connector_withdraw(positionId, tokens, toWithdraw, recipient);
  }

  /// @inheritdoc IEarnStrategy
  function specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawalData,
    address recipient
  )
    external
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    return _connector_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawalData, recipient);
  }

  /// @inheritdoc IEarnStrategy
  function migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    external
    returns (bytes memory)
  {
    return _connector_migrateToNewStrategy(newStrategy, migrationData);
  }

  /// @inheritdoc IEarnStrategy
  function strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationResultData
  )
    external
  {
    _connector_strategyRegistered(strategyId, oldStrategy, migrationResultData);
  }

  function _delayedWithdrawalAdapter() internal view virtual override returns (IDelayedWithdrawalAdapter) {
    return __delayedWithdrawalAdapter;
  }

  function assetYieldCoefficient() external pure override returns (uint256, uint256) {
    return (1e18, 1e18);
  }

  function rewardEmissionsPerSecondPerAsset() external pure override returns (uint256[] memory, uint256[] memory) {
    return (new uint256[](0), new uint256[](0));
  }
}
