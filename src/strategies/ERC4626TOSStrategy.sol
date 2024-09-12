// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { IERC4626, IERC20 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {
  IEarnStrategy,
  SpecialWithdrawalCode,
  StrategyId,
  IEarnVault,
  IEarnStrategyRegistry,
  IERC165
} from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IEarnBalmyStrategy } from "../interfaces/IEarnBalmyStrategy.sol";
import { IDelayedWithdrawalAdapter } from "src/delayed-withdrawal-manager/DelayedWithdrawalManager.sol";

import { ERC4626Connector } from "./connector/ERC4626Connector.sol";
import { TOSCreationValidation } from "./creation-validation/TOSCreationValidation.sol";

contract ERC4626TOSStrategy is IEarnBalmyStrategy, ERC4626Connector, TOSCreationValidation {
  error OnlyVault();
  error OnlyStrategyRegistry();

  /// @inheritdoc IEarnStrategy
  IEarnVault public immutable vault;
  /// @inheritdoc IEarnStrategy
  string public description;

  // slither-disable-next-line naming-convention
  IERC4626 internal immutable _ERC4626Vault;
  IERC20 internal immutable _vaultAsset;

  constructor(
    // General
    IEarnVault vault_,
    string memory description_,
    // ERC4626 connector
    IERC4626 farmVault,
    // TOS validation
    bytes memory tos,
    address[] memory tosAdmins
  ) {
    vault = vault_;
    description = description_;
    _ERC4626Vault = farmVault;
    _vaultAsset = IERC20(farmVault.asset());
    _connector_init();
    _creationValidation_init(tos, tosAdmins);
  }

  // slither-disable-next-line naming-convention
  function ERC4626Vault() public view override returns (IERC4626) {
    return _ERC4626Vault;
  }

  function _asset() internal view override returns (IERC20) {
    return _vaultAsset;
  }

  /// @inheritdoc IEarnStrategy
  function registry() public view returns (IEarnStrategyRegistry) {
    return vault.STRATEGY_REGISTRY();
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public view override(IERC165, TOSCreationValidation) returns (bool) {
    return interfaceId == type(IEarnBalmyStrategy).interfaceId || interfaceId == type(IEarnStrategy).interfaceId
      || TOSCreationValidation.supportsInterface(interfaceId);
  }

  /// @inheritdoc IEarnStrategy
  function asset() external view returns (address) {
    return _connector_asset();
  }

  /// @inheritdoc IEarnStrategy
  function allTokens() external view returns (address[] memory) {
    return _connector_allTokens();
  }

  /// @inheritdoc IEarnStrategy
  function isDepositTokenSupported(address depositToken) external view returns (bool) {
    return _connector_isDepositTokenSupported(depositToken);
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
    return _connector_supportedWithdrawals();
  }

  /// @inheritdoc IEarnStrategy
  function isSpecialWithdrawalSupported(SpecialWithdrawalCode withdrawalCode) external view returns (bool) {
    return _connector_isSpecialWithdrawalSupported(withdrawalCode);
  }

  /// @inheritdoc IEarnStrategy
  function supportedSpecialWithdrawals() external view returns (SpecialWithdrawalCode[] memory) {
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
  function validatePositionCreation(address sender, bytes calldata creationData) external view {
    _creationValidation_validate(sender, creationData);
  }

  /// @inheritdoc IEarnStrategy
  function deposited(
    address depositToken,
    uint256 depositAmount
  )
    external
    payable
    onlyVault
    returns (uint256 assetsDeposited)
  {
    return _connector_deposit(depositToken, depositAmount);
  }

  /// @inheritdoc IEarnStrategy
  function withdraw(
    uint256 positionId,
    address[] memory tokens,
    uint256[] memory toWithdraw,
    address recipient
  )
    external
    onlyVault
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
    onlyStrategyRegistry
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
    onlyStrategyRegistry
  {
    _connector_strategyRegistered(strategyId, oldStrategy, migrationResultData);
  }

  modifier onlyStrategyRegistry() {
    if (msg.sender != address(registry())) revert OnlyStrategyRegistry();
    _;
  }

  modifier onlyVault() {
    if (msg.sender != address(vault)) revert OnlyVault();
    _;
  }
}
