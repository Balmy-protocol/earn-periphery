// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IFeeManager, StrategyId } from "../interfaces/IFeeManager.sol";
import { Fees } from "../types/Fees.sol";

contract FeeManager is IFeeManager, AccessControlDefaultAdminRules {
  /// @inheritdoc IFeeManager
  bytes32 public constant MANAGE_FEES_ROLE = keccak256("MANAGE_FEES_ROLE");

  /// @inheritdoc IFeeManager
  uint16 public constant MAX_FEE = 7500; // 75%

  mapping(StrategyId strategy => Fees) internal _fees;
  mapping(StrategyId strategy => bool) internal _strategiesWithFees;
  Fees public _defaultFees;

  constructor(
    address superAdmin,
    address[] memory initialManageFeeAdmins,
    Fees memory initialDefaultFees
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    _assignRoles(MANAGE_FEES_ROLE, initialManageFeeAdmins);
    _setDefaultFees(initialDefaultFees);
  }

  /// @inheritdoc IFeeManager
  function getFees(StrategyId strategyId) external view override returns (Fees memory) {
    if (_strategiesWithFees[strategyId]) {
      return _fees[strategyId];
    }
    return _defaultFees;
  }

  /// @inheritdoc IFeeManager
  function updateFees(StrategyId strategyId, Fees memory newFees) external override onlyRole(MANAGE_FEES_ROLE) {
    if (
      newFees.depositFee > MAX_FEE || newFees.withdrawFee > MAX_FEE || newFees.performanceFee > MAX_FEE
        || newFees.saveFee > MAX_FEE
    ) {
      revert FeesGreaterThanMaximum();
    }

    _fees[strategyId] = newFees;
    _strategiesWithFees[strategyId] = true;
    emit StrategyFeesChanged(strategyId, newFees);
  }

  /// @inheritdoc IFeeManager
  function defaultFees() external view override returns (Fees memory) {
    return _defaultFees;
  }

  /// @inheritdoc IFeeManager
  function setToDefault(StrategyId strategyId) external override onlyRole(MANAGE_FEES_ROLE) {
    delete _fees[strategyId];
    delete _strategiesWithFees[strategyId];
  }

  /// @inheritdoc IFeeManager
  function setDefaultFees(Fees memory newFees) external override onlyRole(MANAGE_FEES_ROLE) {
    _setDefaultFees(newFees);
  }

  function _setDefaultFees(Fees memory newFees) internal {
    if (
      newFees.depositFee > MAX_FEE || newFees.withdrawFee > MAX_FEE || newFees.performanceFee > MAX_FEE
        || newFees.saveFee > MAX_FEE
    ) {
      revert FeesGreaterThanMaximum();
    }

    _defaultFees = newFees;
    emit DefaultFeesChanged(newFees);
  }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }
}
