// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IFeeManager, StrategyId } from "../interfaces/IFeeManager.sol";
import { Fees } from "../types/Fees.sol";

struct StrategyFees {
  bool isSet;
  Fees fees;
}

contract FeeManager is IFeeManager, AccessControlDefaultAdminRules {
  /// @inheritdoc IFeeManager
  bytes32 public constant MANAGE_FEES_ROLE = keccak256("MANAGE_FEES_ROLE");

  /// @inheritdoc IFeeManager
  uint16 public constant MAX_FEE = 5000; // 50%

  mapping(StrategyId strategy => StrategyFees fees) internal _fees;
  Fees internal _defaultFees;

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
  // solhint-disable no-empty-blocks
  function strategySelfConfigure(bytes calldata data) external override {
    // Does nothing, we we want to have this function for future fee manager implementations
  }

  /// @inheritdoc IFeeManager
  function getFees(StrategyId strategyId) external view override returns (Fees memory) {
    StrategyFees memory strategyFees = _fees[strategyId];
    if (strategyFees.isSet) {
      return strategyFees.fees;
    }
    return _defaultFees;
  }

  /// @inheritdoc IFeeManager
  function updateFees(StrategyId strategyId, Fees memory newFees) external override onlyRole(MANAGE_FEES_ROLE) {
    _revertIfNewFeesGreaterThanMaximum(newFees);
    _fees[strategyId] = StrategyFees(true, newFees);
    emit StrategyFeesChanged(strategyId, newFees);
  }

  /// @inheritdoc IFeeManager
  function defaultFees() external view override returns (Fees memory) {
    return _defaultFees;
  }

  /// @inheritdoc IFeeManager
  function setToDefault(StrategyId strategyId) external override onlyRole(MANAGE_FEES_ROLE) {
    delete _fees[strategyId];
  }

  /// @inheritdoc IFeeManager
  function hasDefaultFees(StrategyId strategyId) external view override returns (bool) {
    return !_fees[strategyId].isSet;
  }

  /// @inheritdoc IFeeManager
  function setDefaultFees(Fees memory newFees) external override onlyRole(MANAGE_FEES_ROLE) {
    _setDefaultFees(newFees);
  }

  function _setDefaultFees(Fees memory newFees) internal {
    _revertIfNewFeesGreaterThanMaximum(newFees);
    _defaultFees = newFees;
    emit DefaultFeesChanged(newFees);
  }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }

  function _revertIfNewFeesGreaterThanMaximum(Fees memory newFees) internal pure {
    if (
      newFees.depositFee > MAX_FEE || newFees.withdrawFee > MAX_FEE || newFees.performanceFee > MAX_FEE
        || newFees.rescueFee > MAX_FEE
    ) {
      revert FeesGreaterThanMaximum();
    }
  }
}
