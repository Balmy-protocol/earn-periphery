// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { AccessControlDefaultAdminRules } from
  "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import { IEarnStrategy, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { ILiquidityMiningManager, ILiquidityMiningManagerCore } from "src/interfaces/ILiquidityMiningManager.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @notice A liquidity mining manager that allows the configuration of liquidity mining campaigns
 */
contract LiquidityMiningManager is ILiquidityMiningManager, AccessControlDefaultAdminRules {
  using SafeERC20 for IERC20;
  using Math for uint256;
  using SafeCast for uint256;
  using Token for address;

  error UnauthorizedCaller();
  error InvalidReward();
  error InsufficientBalance();

  struct Campaign {
    uint88 emissionPerSecond;
    uint32 deadline;
    uint104 pendingFromLastUpdate;
    uint32 lastUpdated;
  }

  /// @inheritdoc ILiquidityMiningManager
  bytes32 public constant MANAGE_CAMPAIGNS_ROLE = keccak256("MANAGE_CAMPAIGNS_ROLE");

  /// @inheritdoc ILiquidityMiningManager
  // slither-disable-next-line naming-convention
  IEarnStrategyRegistry public immutable STRATEGY_REGISTRY;

  mapping(bytes32 strategyAndReward => Campaign campaign) internal _campaigns;

  mapping(StrategyId strategyId => address[] rewards) internal _rewards;

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
  function rewardAmount(StrategyId strategyId, address token) external view override returns (uint256) {
    Campaign memory campaign = _campaigns[_key(strategyId, token)];
    return _calculateRewardAmount(campaign);
  }

  /// @inheritdoc ILiquidityMiningManagerCore
  function rewards(StrategyId strategyId) external view override returns (address[] memory) {
    return _rewards[strategyId];
  }

  /// @inheritdoc ILiquidityMiningManagerCore
  function campaignEmission(
    StrategyId strategyId,
    address token
  )
    external
    view
    returns (uint256 emissionPerSecond, uint256 deadline)
  {
    Campaign memory campaign = _campaigns[_key(strategyId, token)];
    return (campaign.emissionPerSecond, campaign.deadline);
  }

  /// @inheritdoc ILiquidityMiningManagerCore
  //slither-disable-start timestamp
  function claim(
    StrategyId strategyId,
    address token,
    uint256 amount,
    address recipient
  )
    external
    override
    onlyStrategy(strategyId)
  {
    bytes32 key = _key(strategyId, token);
    Campaign storage campaign = _campaigns[key];
    Campaign memory campaignMem = campaign;
    uint256 balance = _calculateRewardAmount(campaignMem);
    if (amount > balance) {
      revert InsufficientBalance();
    }
    campaign.pendingFromLastUpdate = (balance - amount).toUint104();
    campaign.lastUpdated = block.timestamp.toUint32();

    token.transfer({ recipient: recipient, amount: amount });
  }
  //slither-disable-end timestamp

  /// @inheritdoc ILiquidityMiningManagerCore
  // solhint-disable-next-line no-empty-blocks
  function deposited(StrategyId strategyId, uint256 assetsDeposited) external override {
    // Does nothing, but we want to have this function for future liquidity mining manager implementations
  }

  /// @inheritdoc ILiquidityMiningManagerCore
  // solhint-disable-next-line no-empty-blocks
  function withdrew(StrategyId strategyId, uint256 assetsWithdrawn) external override {
    // Does nothing, but we want to have this function for future liquidity mining manager implementations
  }

  /// @inheritdoc ILiquidityMiningManagerCore
  function strategySelfConfigure(bytes calldata data) external payable {
    if (data.length == 0) {
      return;
    }

    // Find the caller's strategy id
    StrategyId strategyId = STRATEGY_REGISTRY.assignedId(IEarnStrategy(msg.sender));
    if (strategyId == StrategyIdConstants.NO_STRATEGY) {
      revert UnauthorizedCaller();
    }

    (address reward, uint256 amount, uint256 duration) = abi.decode(data, (address, uint256, uint256));
    _addToCampaign(strategyId, reward, amount, duration);
  }

  /// @inheritdoc ILiquidityMiningManager
  function setCampaign(
    StrategyId strategyId,
    address reward,
    uint256 emissionPerSecond,
    uint256 duration
  )
    external
    payable
    override
    onlyRole(MANAGE_CAMPAIGNS_ROLE)
  {
    _setCampaign(strategyId, reward, emissionPerSecond, duration);
  }

  /// @inheritdoc ILiquidityMiningManager
  function addToCampaign(
    StrategyId strategyId,
    address reward,
    uint256 amount,
    uint256 duration
  )
    external
    payable
    onlyRole(MANAGE_CAMPAIGNS_ROLE)
  {
    _addToCampaign(strategyId, reward, amount, duration);
  }

  //slither-disable-start timestamp
  function _addToCampaign(StrategyId strategyId, address reward, uint256 amount, uint256 newDuration) internal {
    Campaign storage campaign = _campaigns[_key(strategyId, reward)];
    Campaign memory campaignMem = campaign;
    uint256 amountLeft = (campaignMem.deadline > block.timestamp)
      ? campaignMem.emissionPerSecond * (campaignMem.deadline - block.timestamp)
      : 0;
    uint256 newEmissionPerSecond = (amountLeft + amount) / newDuration;
    _setCampaign(campaign, campaignMem, strategyId, reward, newEmissionPerSecond, newDuration);
  }

  function _setCampaign(StrategyId strategyId, address reward, uint256 emissionPerSecond, uint256 duration) internal {
    Campaign storage campaign = _campaigns[_key(strategyId, reward)];
    Campaign memory campaignMem = campaign;
    _setCampaign(campaign, campaignMem, strategyId, reward, emissionPerSecond, duration);
  }

  //slither-disable-next-line reentrancy-no-eth
  function _setCampaign(
    Campaign storage campaign,
    Campaign memory campaignMem,
    StrategyId strategyId,
    address reward,
    uint256 emissionPerSecond,
    uint256 duration
  )
    internal
  {
    if (campaignMem.lastUpdated == 0) {
      IEarnStrategy strategy = STRATEGY_REGISTRY.getStrategy(strategyId);
      if (strategy.asset() == reward) {
        revert InvalidReward();
      }
      _rewards[strategyId].push(reward);
    } else {
      // Update the pending rewards
      campaign.pendingFromLastUpdate = (_calculateRewardAmount(campaign)).toUint104();
    }
    uint256 deadline = block.timestamp + duration;
    uint256 balanceNeeded = emissionPerSecond * duration;
    uint256 currentBalance = (campaignMem.deadline > block.timestamp)
      ? campaignMem.emissionPerSecond * (campaignMem.deadline - block.timestamp)
      : 0;
    if (currentBalance < balanceNeeded) {
      uint256 missing = balanceNeeded - currentBalance;
      if (reward == Token.NATIVE_TOKEN) {
        if (msg.value < missing) {
          revert InsufficientBalance();
        }
        // Return the excess tokens
        if (msg.value > missing) {
          Token.NATIVE_TOKEN.transfer(msg.sender, msg.value - missing);
        }
      } else {
        // Transfer the missing tokens
        IERC20(reward).safeTransferFrom(msg.sender, address(this), missing);
      }
    } else if (currentBalance > balanceNeeded) {
      // Return the excess tokens
      // slither-disable-next-line arbitrary-send-eth,reentrancy-eth,reentrancy-events,reentrancy-unlimited-gas
      reward.transfer({ recipient: msg.sender, amount: currentBalance - balanceNeeded });
    }

    campaign.emissionPerSecond = emissionPerSecond.toUint88();
    campaign.deadline = deadline.toUint32();
    campaign.lastUpdated = block.timestamp.toUint32();
    emit CampaignSet(strategyId, reward, emissionPerSecond, deadline);
  }
  //slither-disable-end timestamp

  /// @inheritdoc ILiquidityMiningManager
  function abortCampaign(
    StrategyId strategyId,
    address reward,
    address recipient
  )
    external
    onlyRole(MANAGE_CAMPAIGNS_ROLE)
  {
    bytes32 key = _key(strategyId, reward);
    Campaign memory campaign = _campaigns[key];

    delete _campaigns[key];

    uint256 remainingBalance = campaign.pendingFromLastUpdate
      + (
        campaign.lastUpdated < campaign.deadline
          ? campaign.emissionPerSecond * (campaign.deadline - campaign.lastUpdated)
          : 0
      );

    emit CampaignAborted(strategyId, reward);

    reward.transfer({ recipient: recipient, amount: remainingBalance });
  }

  function _assignRoles(bytes32 role, address[] memory accounts) internal {
    for (uint256 i; i < accounts.length; ++i) {
      _grantRole(role, accounts[i]);
    }
  }

  function _key(StrategyId strategyId, address token) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(strategyId, token));
  }

  function _calculateRewardAmount(Campaign memory campaign) internal view returns (uint256) {
    return campaign.pendingFromLastUpdate
      + (
        campaign.lastUpdated < campaign.deadline
          ? campaign.emissionPerSecond * (Math.min(block.timestamp, campaign.deadline) - campaign.lastUpdated)
          : 0
      );
  }

  modifier onlyStrategy(StrategyId strategyId) {
    IEarnStrategy strategy = STRATEGY_REGISTRY.getStrategy(strategyId);
    if (msg.sender != address(strategy)) {
      revert UnauthorizedCaller();
    }
    _;
  }
}
