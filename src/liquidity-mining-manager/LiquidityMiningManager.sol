// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IEarnStrategy, StrategyId, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { ILiquidityMiningManager, ILiquidityMiningManagerCore } from "../interfaces/ILiquidityMiningManager.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";

/**
 * @notice A guardian manager that allows the configuration of liquidity mining campaigns
 */
contract LiquidityMiningManager is ILiquidityMiningManager, AccessControlDefaultAdminRules {
  using SafeERC20 for IERC20;

  error UnauthorizedCaller();
  error InvalidReward();
  error InsufficientBalance();

  struct Campaign {
    uint256 emissionPerSecond;
    uint256 deadline;
    uint256 claimed;
    uint256 pendingFromLastUpdate;
    uint256 lastUpdated;
  }

  /// @inheritdoc ILiquidityMiningManager
  bytes32 public constant MANAGE_CAMPAIGNS_ROLE = keccak256("MANAGE_CAMPAIGNS_ROLE");

  /// @inheritdoc ILiquidityMiningManager
  // slither-disable-next-line naming-convention
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;

  mapping(bytes32 strategyAndReward => Campaign campaigns) internal _rewards;

  constructor(
    IEarnStrategyRegistry registry,
    address superAdmin,
    address[] memory initialAdmins
  )
    AccessControlDefaultAdminRules(3 days, superAdmin)
  {
    STRATEGY_REGISTRY = registry;
    _assignRoles(MANAGE_CAMPAIGNS_ROLE, initialAdmins);
  }

  /// @inheritdoc ILiquidityMiningManagerCore
  // solhint-disable-next-line no-empty-blocks
  function rewards(StrategyId strategyId) external view override returns (address[] memory) { }

  /// @inheritdoc ILiquidityMiningManagerCore
  // solhint-disable-next-line no-empty-blocks
  function rewardAmount(StrategyId strategyId, address token) external view override returns (uint256) { }

  /// @inheritdoc ILiquidityMiningManagerCore
  // solhint-disable-next-line no-empty-blocks
  function claim(StrategyId strategyId, address token, uint256 amount, address recipient) external override { }

  /// @inheritdoc ILiquidityMiningManagerCore
  // solhint-disable-next-line no-empty-blocks
  function deposited(StrategyId strategyId, uint256 assetsDeposited) external override {
    // Does nothing, but we we want to have this function for future liquidity mining manager implementations
  }

  /// @inheritdoc ILiquidityMiningManagerCore
  // solhint-disable-next-line no-empty-blocks
  function withdrew(StrategyId strategyId, uint256 assetsWithdrawn) external override {
    // Does nothing, but we we want to have this function for future liquidity mining manager implementations
  }

  /// @inheritdoc ILiquidityMiningManagerCore
  // solhint-disable-next-line no-empty-blocks
  function strategySelfConfigure(bytes calldata data) external override { }

  /// @inheritdoc ILiquidityMiningManager
  function setCampaign(
    StrategyId strategyId,
    address reward,
    uint256 emissionPerSecond,
    uint256 deadline
  )
    external
    payable
    override
    onlyRole(MANAGE_CAMPAIGNS_ROLE)
  {
    bytes32 key = _key(strategyId, reward);
    Campaign storage campaign = _rewards[key];
    if (campaign.lastUpdated == 0) {
      IEarnStrategy strategy = STRATEGY_REGISTRY.getStrategy(strategyId);
      if (strategy.asset() == reward) {
        revert InvalidReward();
      }
    } else {
      // Update the pending rewards
      campaign.pendingFromLastUpdate =
        campaign.emissionPerSecond * (block.timestamp - campaign.lastUpdated) - campaign.claimed;
    }

    uint256 balanceNeeded = emissionPerSecond * (deadline - block.timestamp);
    uint256 currentBalance = campaign.emissionPerSecond * (campaign.deadline - campaign.lastUpdated) - campaign.claimed;
    if (currentBalance < balanceNeeded) {
      // Transfer the missing tokens
      if (reward == Token.NATIVE_TOKEN) {
        if (msg.value < balanceNeeded - currentBalance) {
          revert InsufficientBalance();
        }
      } else {
        IERC20(reward).forceApprove(address(this), balanceNeeded - currentBalance);
        IERC20(reward).safeTransferFrom(msg.sender, address(this), balanceNeeded - currentBalance);
      }
    }
    if (currentBalance > balanceNeeded) {
      // Return the excess tokens
      if (reward == Token.NATIVE_TOKEN) {
        payable(address(msg.sender)).transfer(currentBalance - balanceNeeded);
      } else {
        IERC20(reward).safeTransfer(msg.sender, currentBalance - balanceNeeded);
      }
    }
    campaign.emissionPerSecond = emissionPerSecond;
    campaign.deadline = deadline;
    campaign.lastUpdated = block.timestamp;
    campaign.claimed = 0;

    emit CampaignSet(strategyId, reward, emissionPerSecond, deadline);
  }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }

  function _key(StrategyId strategyId, address token) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(strategyId, token));
  }
}
