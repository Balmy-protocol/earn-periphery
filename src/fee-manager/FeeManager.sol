// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IFeeManager, StrategyId } from "../interfaces/IFeeManager.sol";
import { Fees } from "../types/Fees.sol";

struct StrategyFees {
  bool isSet;
  Fees fees;
  address recipient;
}

struct DefaultFees {
  Fees fees;
  address recipient;
}

contract FeeManager is IFeeManager, AccessControlDefaultAdminRules {
  /// @inheritdoc IFeeManager
  bytes32 public constant MANAGE_FEES_ROLE = keccak256("MANAGE_FEES_ROLE");

  /// @inheritdoc IFeeManager
  uint16 public constant MAX_FEE = 5000; // 50%
  /// @inheritdoc IFeeManager
  DefaultFees public defaultFees;
  mapping(StrategyId strategy => StrategyFees fees) internal _fees;

  constructor(
    address superAdmin,
    address[] memory initialManageFeeAdmins,
    Fees memory initialDefaultFees,
    address initialDefaultFeesRecipient
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    _assignRoles(MANAGE_FEES_ROLE, initialManageFeeAdmins);
    _setDefaultFees(initialDefaultFees, initialDefaultFeesRecipient);
  }

  /// @inheritdoc IFeeManager
  function getFees(StrategyId strategyId) external view override returns (Fees memory, address recipient) {
    StrategyFees memory strategyFees = _fees[strategyId];
    if (strategyFees.isSet) {
      return (strategyFees.fees, strategyFees.recipient);
    }
    DefaultFees memory defaultFees_ = defaultFees;
    return (defaultFees_.fees, defaultFees_.recipient);
  }

  /// @inheritdoc IFeeManager
  function updateFees(
    StrategyId strategyId,
    Fees memory newFees,
    address recipient
  )
    external
    override
    onlyRole(MANAGE_FEES_ROLE)
  {
    _revertIfNewFeesGreaterThanMaximum(newFees);
    _fees[strategyId] = StrategyFees({ isSet: true, fees: newFees, recipient: recipient });
    emit StrategyFeesChanged(strategyId, newFees, recipient);
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
  function setDefaultFees(Fees memory newFees, address recipient) external override onlyRole(MANAGE_FEES_ROLE) {
    _setDefaultFees(newFees, recipient);
  }

  function _setDefaultFees(Fees memory newFees, address recipient) internal {
    _revertIfNewFeesGreaterThanMaximum(newFees);
    defaultFees = DefaultFees({ fees: newFees, recipient: recipient });
    emit DefaultFeesChanged(newFees, recipient);
  }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }

  function _revertIfNewFeesGreaterThanMaximum(Fees memory newFees) internal pure {
    if (
      newFees.depositFee > MAX_FEE || newFees.withdrawFee > MAX_FEE || newFees.performanceFee > MAX_FEE
        || newFees.saveFee > MAX_FEE
    ) {
      revert FeesGreaterThanMaximum();
    }
  }
}
