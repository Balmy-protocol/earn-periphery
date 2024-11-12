// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IEarnStrategy, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IGuardianManager, IGuardianManagerCore, IEarnStrategyRegistry } from "src/interfaces/IGuardianManager.sol";

/**
 * @notice A guardian manager that allows strategies to configure their own guardians and judges
 * @dev This guardian manager supports two different actors:
 *       - Guardians: they can start a rescue process and cancel it
 *       - Judges: they can confirm a rescue process
 *      Each strategy can have different guardians and judges, but this manager also supports global guardians and
 *      judges. These can perform their roles with all strategies, regarding of their strategy-specific config
 */
contract GuardianManager is IGuardianManager, AccessControlDefaultAdminRules {
  error UnauthorizedCaller();
  /// @inheritdoc IGuardianManager

  bytes32 public constant GLOBAL_GUARDIAN_ROLE = keccak256("GLOBAL_GUARDIAN_ROLE");
  /// @inheritdoc IGuardianManager
  bytes32 public constant GLOBAL_JUDGE_ROLE = keccak256("GLOBAL_JUDGE_ROLE");
  /// @inheritdoc IGuardianManager
  bytes32 public constant MANAGE_GUARDIANS_ROLE = keccak256("MANAGE_GUARDIANS_ROLE");
  /// @inheritdoc IGuardianManager
  bytes32 public constant MANAGE_JUDGES_ROLE = keccak256("MANAGE_JUDGES_ROLE");

  /// @inheritdoc IGuardianManager
  // slither-disable-next-line naming-convention
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;

  constructor(
    IEarnStrategyRegistry registry,
    address superAdmin,
    address[] memory initialGlobalGuardians,
    address[] memory initialGlobalJudges,
    address[] memory initialManageGuardiansAdmins,
    address[] memory initialManageJudgesAdmins
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    STRATEGY_REGISTRY = registry;
    _assignRoles(GLOBAL_GUARDIAN_ROLE, initialGlobalGuardians);
    _assignRoles(GLOBAL_JUDGE_ROLE, initialGlobalJudges);
    _assignRoles(MANAGE_GUARDIANS_ROLE, initialManageGuardiansAdmins);
    _assignRoles(MANAGE_JUDGES_ROLE, initialManageJudgesAdmins);
  }

  mapping(bytes32 strategyAndAccount => bool isGuardian) internal _isGuardian;
  mapping(bytes32 strategyAndAccount => bool isJudge) internal _isJudge;

  /// @inheritdoc IGuardianManager
  function isGuardian(StrategyId strategyId, address account) public view returns (bool) {
    return _isGuardian[_key(strategyId, account)];
  }

  /// @inheritdoc IGuardianManager
  function isJudge(StrategyId strategyId, address account) public view returns (bool) {
    return _isJudge[_key(strategyId, account)];
  }

  /// @inheritdoc IGuardianManagerCore
  function canStartRescue(StrategyId strategyId, address account) external view returns (bool) {
    return isGuardian(strategyId, account) || hasRole(GLOBAL_GUARDIAN_ROLE, account);
  }
  /// @inheritdoc IGuardianManagerCore

  function canCancelRescue(StrategyId strategyId, address account) external view returns (bool) {
    return isGuardian(strategyId, account) || hasRole(GLOBAL_GUARDIAN_ROLE, account);
  }
  /// @inheritdoc IGuardianManagerCore

  function canConfirmRescue(StrategyId strategyId, address account) external view returns (bool) {
    return isJudge(strategyId, account) || hasRole(GLOBAL_JUDGE_ROLE, account);
  }

  /// @inheritdoc IGuardianManagerCore
  function strategySelfConfigure(bytes calldata data) external {
    if (data.length == 0) {
      return;
    }

    // Find the caller's strategy id
    StrategyId strategyId = STRATEGY_REGISTRY.assignedId(IEarnStrategy(msg.sender));
    if (strategyId == StrategyIdConstants.NO_STRATEGY) {
      revert UnauthorizedCaller();
    }

    (address[] memory guardians, address[] memory judges) = abi.decode(data, (address[], address[]));
    if (guardians.length > 0) {
      _assignGuardians(strategyId, guardians);
    }
    if (judges.length > 0) {
      _assignJudges(strategyId, judges);
    }
  }
  /// @inheritdoc IGuardianManagerCore

  function rescueStarted(StrategyId strategyId) external {
    emit RescueStarted(strategyId);
  }
  /// @inheritdoc IGuardianManagerCore

  function rescueCancelled(StrategyId strategyId) external {
    emit RescueCancelled(strategyId);
  }
  /// @inheritdoc IGuardianManagerCore

  function rescueConfirmed(StrategyId strategyId) external {
    emit RescueConfirmed(strategyId);
  }

  /// @inheritdoc IGuardianManager
  function assignGuardians(
    StrategyId strategyId,
    address[] calldata guardians
  )
    external
    onlyRole(MANAGE_GUARDIANS_ROLE)
  {
    _assignGuardians(strategyId, guardians);
  }

  /// @inheritdoc IGuardianManager
  function removeGuardians(
    StrategyId strategyId,
    address[] calldata guardians
  )
    external
    onlyRole(MANAGE_GUARDIANS_ROLE)
  {
    for (uint256 i; i < guardians.length; ++i) {
      _isGuardian[_key(strategyId, guardians[i])] = false;
    }
    emit GuardiansRemoved(strategyId, guardians);
  }

  /// @inheritdoc IGuardianManager
  function assignJudges(StrategyId strategyId, address[] calldata judges) external onlyRole(MANAGE_JUDGES_ROLE) {
    _assignJudges(strategyId, judges);
  }

  /// @inheritdoc IGuardianManager
  function removeJudges(StrategyId strategyId, address[] calldata judges) external onlyRole(MANAGE_JUDGES_ROLE) {
    for (uint256 i; i < judges.length; ++i) {
      _isJudge[_key(strategyId, judges[i])] = false;
    }
    emit JudgesRemoved(strategyId, judges);
  }

  function _assignGuardians(StrategyId strategyId, address[] memory guardians) internal {
    for (uint256 i; i < guardians.length; ++i) {
      _isGuardian[_key(strategyId, guardians[i])] = true;
    }
    emit GuardiansAssigned(strategyId, guardians);
  }

  function _assignJudges(StrategyId strategyId, address[] memory judges) internal {
    for (uint256 i; i < judges.length; ++i) {
      _isJudge[_key(strategyId, judges[i])] = true;
    }
    emit JudgesAssigned(strategyId, judges);
  }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }

  function _key(StrategyId strategyId, address account) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(strategyId, account));
  }
}
