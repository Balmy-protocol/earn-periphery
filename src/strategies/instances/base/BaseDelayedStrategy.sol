// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  IEarnStrategy, SpecialWithdrawalCode, IEarnVault, IERC165
} from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { BaseConnector, IDelayedWithdrawalAdapter } from "../../layers/connector/base/BaseConnector.sol";
import { BaseCreationValidation } from "../../layers/creation-validation/base/BaseCreationValidation.sol";
import { BaseFees } from "../../layers/fees/base/BaseFees.sol";
import { BaseLiquidityMining } from "../../layers/liquidity-mining/base/BaseLiquidityMining.sol";

/**
 * @title Earn Base Strategy with Delayed Withdrawals support
 * @notice This is a base strategy that implements the core functionality of an Earn Strategy and prepared to support
 *         delayed withdrawals. It has the following layers:
 *         1. Liquidity mining
 *         2. Fees
 *         3. Creation validation
 *         4. Connector
 *
 *         They are executed in the same order as presented above. Strategies that inherit from this contract must
 *         define implementations for each of these layers, and they might need to implement some additional logic
 *         in the strategy itself.
 */
abstract contract BaseDelayedStrategy is
  IEarnBalmyStrategy,
  BaseLiquidityMining,
  BaseFees,
  BaseCreationValidation,
  BaseConnector
{
  error OnlyVault();
  error OnlyStrategyRegistry();

  StrategyId internal _strategyId;

  /// @dev Some strategies have the native token as the asset
  receive() external payable { }

  function strategyId() public view virtual returns (StrategyId) {
    return _strategyId;
  }

  /// @inheritdoc IEarnStrategy
  function vault() public view override returns (IEarnVault) {
    return _earnVault();
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
    return interfaceId == type(IEarnBalmyStrategy).interfaceId || interfaceId == type(IEarnStrategy).interfaceId
      || interfaceId == type(IERC165).interfaceId;
  }

  /// @inheritdoc IEarnStrategy
  function asset() external view returns (address) {
    return _connector_asset();
  }

  /// @inheritdoc IEarnStrategy
  function allTokens() external view returns (address[] memory) {
    return _liquidity_mining_allTokens();
  }

  /// @inheritdoc IEarnStrategy
  function supportedDepositTokens() external view returns (address[] memory) {
    return _connector_supportedDepositTokens();
  }

  /// @inheritdoc IEarnStrategy
  function maxDeposit(address depositToken) external view returns (uint256) {
    return _connector_maxDeposit(depositToken);
  }

  /// @inheritdoc IEarnStrategy
  function supportedWithdrawals() external view returns (WithdrawalType[] memory) {
    return _liquidity_mining_supportedWithdrawals();
  }

  /// @inheritdoc IEarnStrategy
  function supportedSpecialWithdrawals() external view returns (SpecialWithdrawalCode[] memory) {
    return _connector_supportedSpecialWithdrawals();
  }

  /// @inheritdoc IEarnStrategy
  function maxWithdraw() external view returns (address[] memory, uint256[] memory) {
    return _liquidity_mining_maxWithdraw();
  }

  /// @inheritdoc IEarnBalmyStrategy
  function delayedWithdrawalAdapter(address token) external view returns (IDelayedWithdrawalAdapter) {
    return _connector_delayedWithdrawalAdapter(token);
  }

  /// @inheritdoc IEarnStrategy
  function fees() external view returns (IEarnStrategy.FeeType[] memory types, uint16[] memory bps) {
    return _fees_fees();
  }

  /// @inheritdoc IEarnStrategy
  function totalBalances() external view returns (address[] memory tokens, uint256[] memory balances) {
    return _liquidity_mining_totalBalances();
  }

  /// @inheritdoc IEarnStrategy
  function validatePositionCreation(address sender, bytes calldata creationData) external {
    _creationValidation_validate(sender, creationData);
  }

  /// @inheritdoc IEarnStrategy
  function deposit(
    address depositToken,
    uint256 depositAmount
  )
    external
    payable
    onlyVault
    returns (uint256 assetsDeposited)
  {
    return _liquidity_mining_deposit(depositToken, depositAmount);
  }

  /// @inheritdoc IEarnStrategy
  function withdraw(
    uint256 positionId,
    address[] calldata tokens,
    uint256[] calldata toWithdraw,
    address recipient
  )
    external
    onlyVault
  {
    return _liquidity_mining_withdraw(positionId, tokens, toWithdraw, recipient);
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
    onlyVault
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    return _liquidity_mining_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawalData, recipient);
  }

  /// @inheritdoc IEarnStrategy
  function migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata migrationData
  )
    external
    onlyStrategyRegistry
    returns (bytes memory)
  {
    _strategyId = StrategyIdConstants.NO_STRATEGY;
    return _connector_migrateToNewStrategy(newStrategy, migrationData);
  }

  /// @inheritdoc IEarnStrategy
  function strategyRegistered(
    StrategyId strategyId_,
    IEarnStrategy oldStrategy,
    bytes calldata migrationResultData
  )
    external
    onlyStrategyRegistry
  {
    _strategyId = strategyId_;
    _connector_strategyRegistered(strategyId_, oldStrategy, migrationResultData);
  }

  modifier onlyStrategyRegistry() {
    if (msg.sender != address(vault().STRATEGY_REGISTRY())) revert OnlyStrategyRegistry();
    _;
  }

  modifier onlyVault() {
    if (msg.sender != address(vault())) revert OnlyVault();
    _;
  }

  // slither-disable-start naming-convention,dead-code
  function _baseStrategy_registerStrategy(address owner) internal returns (StrategyId) {
    return vault().STRATEGY_REGISTRY().registerStrategy(owner);
  }

  ////////////////////////////////////////////////////////
  ///////////////////    LIQ MINING    ///////////////////
  ////////////////////////////////////////////////////////

  function _liquidity_mining_underlying_allTokens() internal view override returns (address[] memory tokens) {
    return _connector_allTokens();
  }

  function _liquidity_mining_underlying_maxWithdraw()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    return _connector_maxWithdraw();
  }

  function _liquidity_mining_underlying_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    return _fees_totalBalances();
  }

  function _liquidity_mining_underlying_supportedWithdrawals()
    internal
    view
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return _connector_supportedWithdrawals();
  }

  function _liquidity_mining_underlying_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  {
    return _fees_deposit(depositToken, depositAmount);
  }

  function _liquidity_mining_underlying_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    override
  {
    _fees_withdraw(positionId, tokens, toWithdraw, recipient);
  }

  function _liquidity_mining_underlying_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    return _fees_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
  }

  ////////////////////////////////////////////////////////
  ///////////////////       FEES       ///////////////////
  ////////////////////////////////////////////////////////
  function _fees_underlying_tokens() internal view override returns (address[] memory tokens) {
    return _connector_allTokens();
  }

  function _fees_underlying_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    return _connector_totalBalances();
  }

  function _fees_underlying_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  {
    return _connector_deposit({ depositToken: depositToken, depositAmount: depositAmount, takeFromCaller: true });
  }

  function _fees_underlying_withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    internal
    override
  {
    return _connector_withdraw(positionId, tokens, toWithdraw, recipient);
  }

  function _fees_underlying_specialWithdraw(
    uint256 positionId,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata withdrawData,
    address recipient
  )
    internal
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    return _connector_specialWithdraw(positionId, withdrawalCode, toWithdraw, withdrawData, recipient);
  }

  // slither-disable-next-line naming-convention
  function _fees_underlying_supportedWithdrawals()
    internal
    view
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory)
  {
    return _connector_supportedWithdrawals();
  }

  ////////////////////////////////////////////////////////
  ///////////////////     VIRTUAL      ///////////////////
  ////////////////////////////////////////////////////////
  function _earnVault() internal view virtual returns (IEarnVault);

  // slither-disable-end naming-convention,dead-code
}
