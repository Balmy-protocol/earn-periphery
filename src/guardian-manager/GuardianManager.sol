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

  /// @inheritdoc IGuardianManager
  function isGuardian(StrategyId strategyId, address account) public view returns (bool) { }

  /// @inheritdoc IGuardianManager
  function isJudge(StrategyId strategyId, address account) public view returns (bool) { }

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
  function assignGuardians(StrategyId strategyId, address[] memory guardians) public { }

  /// @inheritdoc IGuardianManager
  function removeGuardians(StrategyId strategyId, address[] memory guardians) external { }

  /// @inheritdoc IGuardianManager
  function assignJudges(StrategyId strategyId, address[] memory judges) public { }

  /// @inheritdoc IGuardianManager
  function removeJudges(StrategyId strategyId, address[] memory judges) external { }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }
}
