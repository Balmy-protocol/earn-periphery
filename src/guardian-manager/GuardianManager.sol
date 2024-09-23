// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IGuardianManager, IGuardianManagerCore, IEarnStrategyRegistry } from "../interfaces/IGuardianManager.sol";

/**
 * @notice A guardian manager that allows strategies to configure their own guardians and judges
 * @dev This guardian manager supports two different actors:
 *       - Guardians: they can start a rescue process and cancel it
 *       - Judges: they can confirm a rescue process
 *      Each strategy can have different guardians and judges, but this manager also supports global guardians and
 *      judges. These can perform their roles with all strategies, regarding of their strategy-specific config
 */
contract GuardianManager is IGuardianManager, AccessControlDefaultAdminRules {
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
  function canStartRescue(StrategyId strategyId, address account) external view returns (bool) { }
  /// @inheritdoc IGuardianManagerCore

  function canCancelRescue(StrategyId strategyId, address account) external view returns (bool) { }
  /// @inheritdoc IGuardianManagerCore

  function canConfirmRescue(StrategyId strategyId, address account) external view returns (bool) { }

  /// @inheritdoc IGuardianManagerCore
  function strategySelfConfigure(bytes calldata data) external { }
  /// @inheritdoc IGuardianManagerCore
  // solhint-disable-next-line no-empty-blocks
  function rescueStarted(StrategyId strategyId) external {
    // Does nothing, but we we want to have this function for future guardian manager implementations
  }
  /// @inheritdoc IGuardianManagerCore
  // solhint-disable-next-line no-empty-blocks
  function rescueCancelled(StrategyId strategyId) external {
    // Does nothing, but we we want to have this function for future guardian manager implementations
  }
  /// @inheritdoc IGuardianManagerCore
  // solhint-disable-next-line no-empty-blocks
  function rescueConfirmed(StrategyId strategyId) external {
    // Does nothing, but we we want to have this function for future guardian manager implementations
  }

  /// @inheritdoc IGuardianManager
  function assignGuardians(StrategyId strategyId, address[] calldata guardians) public onlyRole(MANAGE_GUARDIANS_ROLE) {
    for (uint256 i; i < guardians.length; ++i) {
      _isGuardian[_key(strategyId, guardians[i])] = true;
    }
    emit GuardiansAssigned(strategyId, guardians);
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
  function assignJudges(StrategyId strategyId, address[] calldata judges) public onlyRole(MANAGE_JUDGES_ROLE) {
    for (uint256 i; i < judges.length; ++i) {
      _isJudge[_key(strategyId, judges[i])] = true;
    }
    emit JudgesAssigned(strategyId, judges);
  }

  /// @inheritdoc IGuardianManager
  function removeJudges(StrategyId strategyId, address[] calldata judges) external onlyRole(MANAGE_JUDGES_ROLE) {
    for (uint256 i; i < judges.length; ++i) {
      _isJudge[_key(strategyId, judges[i])] = false;
    }
    emit JudgesRemoved(strategyId, judges);
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
