// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IFeeManager, IFeeManagerCore, StrategyId, IEarnStrategyRegistry } from "src/interfaces/IFeeManager.sol";
import { Fees } from "src/types/Fees.sol";
import { IEarnStrategy } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";

struct StrategyFees {
  bool isSet;
  Fees fees;
}

contract FeeManager is IFeeManager, AccessControlDefaultAdminRules {
  error UnauthorizedCaller();

  /// @inheritdoc IFeeManager
  bytes32 public constant MANAGE_FEES_ROLE = keccak256("MANAGE_FEES_ROLE");

  /// @inheritdoc IFeeManager
  bytes32 public constant WITHDRAW_FEES_ROLE = keccak256("WITHDRAW_FEES_ROLE");

  /// @inheritdoc IFeeManager
  uint16 public constant MAX_FEE = 5000; // 50%

  /// @inheritdoc IFeeManager
  // slither-disable-next-line naming-convention
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;

  mapping(StrategyId strategy => StrategyFees fees) internal _fees;
  Fees internal _defaultFees;

  constructor(
    IEarnStrategyRegistry registry,
    address superAdmin,
    address[] memory initialManageFeeAdmins,
    address[] memory initialWithdrawFeeAdmins,
    Fees memory initialDefaultFees
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    STRATEGY_REGISTRY = registry;
    _assignRoles(MANAGE_FEES_ROLE, initialManageFeeAdmins);
    _assignRoles(WITHDRAW_FEES_ROLE, initialWithdrawFeeAdmins);
    _setDefaultFees(initialDefaultFees);
  }

  /// @inheritdoc IFeeManagerCore
  // solhint-disable-next-line no-empty-blocks
  function strategySelfConfigure(bytes calldata data) external override {
    if (data.length == 0) {
      return;
    }

    // Find the caller's strategy id
    StrategyId strategyId = STRATEGY_REGISTRY.assignedId(IEarnStrategy(msg.sender));
    if (strategyId == StrategyIdConstants.NO_STRATEGY) {
      revert UnauthorizedCaller();
    }

    // Decode the fees from the data and assign it to the strategy
    Fees memory newFees = abi.decode(data, (Fees));
    _updateFees(strategyId, newFees);
  }

  /// @inheritdoc IFeeManagerCore
  function getFees(StrategyId strategyId) external view override returns (Fees memory) {
    StrategyFees memory strategyFees = _fees[strategyId];
    if (strategyFees.isSet) {
      return strategyFees.fees;
    }
    return _defaultFees;
  }

  /// @inheritdoc IFeeManager
  function updateFees(StrategyId strategyId, Fees calldata newFees) external override onlyRole(MANAGE_FEES_ROLE) {
    _updateFees(strategyId, newFees);
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
  function setDefaultFees(Fees calldata newFees) external override onlyRole(MANAGE_FEES_ROLE) {
    _setDefaultFees(newFees);
  }

  /// @inheritdoc IFeeManagerCore
  function canWithdrawFees(StrategyId, address caller) external view returns (bool) {
    return hasRole(WITHDRAW_FEES_ROLE, caller);
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

  function _updateFees(StrategyId strategyId, Fees memory newFees) internal {
    _revertIfNewFeesGreaterThanMaximum(newFees);
    _fees[strategyId] = StrategyFees(true, newFees);
    emit StrategyFeesChanged(strategyId, newFees);
  }
}
