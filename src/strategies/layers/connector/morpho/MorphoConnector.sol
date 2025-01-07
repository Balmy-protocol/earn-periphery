// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import { ERC4626Connector, IEarnStrategy } from "../ERC4626Connector.sol";

/**
 * @notice Some farms like Aave v3 generate rewards continuously over time. But other farms (like Morpho) do the
 *         opposite, and generate rewards at discrete points in time. This is common in cases where rewards are
 *         distributed using Merkle trees (like in Morpho's case). The problem is that in this scenario, an attacker
 *         might try to front-run or "sandwich" the yield generation event to keep most tokens to themselves.
 *         This connector provides a workaround for these attacks. The idea is that when a yield generation event is
 *         triggered, the connector won't immediately report those rewards as balance. A manager will have to
 *         manually trigger the distribution for these tokens, but it will be done over time.
 * @dev This implementation makes sure during these manual triggers that configured rewards tokens are not the same as
 *      the asset, since it would break quite a few things. While it's technically possible for the asset to also be
 *      provided as a reward on Morpho, we haven't seen it happen yet. If it does happen, we would probably need to
 *      upgrade the strategy to support re-depositing those rewards into the underlying farm
 */
abstract contract MorphoConnector is ERC4626Connector {
  using Token for address;
  using SafeCast for uint256;

  struct Rewards {
    uint88 emissionPerSecond;
    uint32 deadline;
    uint104 emittedBeforeLastUpdate;
    uint32 lastUpdated;
  }

  error RewardTokenCannotBeAsset();
  error OnlyManagerCanConfigureRewards();

  /// @notice The id for the Morpho Rewards Manager
  bytes32 public constant MORPHO_REWARDS_MANAGER = keccak256("MORPHO_REWARDS_MANAGER");
  /// @notice Returns the rewards for configured for each token
  mapping(address rewardToken => Rewards rewards) public rewards;
  address[] internal _rewardTokens;

  /// @notice The address of the global registry
  function globalRegistry() public view virtual returns (IGlobalEarnRegistry);

  // slither-disable-next-line timestamp
  function configureRewards(address[] memory rewardTokens, uint256 duration) external {
    if (msg.sender != _getRewardsManager()) {
      revert OnlyManagerCanConfigureRewards();
    }
    for (uint256 i = 0; i < rewardTokens.length; ++i) {
      address rewardToken = rewardTokens[i];
      Rewards memory rewardsMem = rewards[rewardToken];
      uint256 alreadyEmitted = _emittedRewards(rewardsMem);
      uint256 unaccounted = rewardToken.balanceOf(address(this)) - alreadyEmitted;
      if (unaccounted > 0) {
        if (rewardsMem.lastUpdated == 0) {
          // If last updated is 0, we are configuring the reward token for the first time and we'll need to add the
          // token to the list of rewards. But first, we'll make sure it's not the asset
          if (rewardToken == _connector_asset()) {
            revert RewardTokenCannotBeAsset();
          }
          _rewardTokens.push(rewardToken);
        }
        rewards[rewardToken] = Rewards({
          deadline: (block.timestamp + duration).toUint32(),
          lastUpdated: uint32(block.timestamp),
          emittedBeforeLastUpdate: alreadyEmitted.toUint104(),
          emissionPerSecond: (unaccounted / duration).toUint88()
        });
      }
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_allTokens() internal view override returns (address[] memory tokens) {
    address[] memory rewardsTokens = _rewardTokens;
    tokens = new address[](1 + rewardsTokens.length);
    tokens[0] = _connector_asset();
    for (uint256 i = 0; i < rewardsTokens.length; ++i) {
      tokens[i + 1] = rewardsTokens[i];
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedWithdrawals()
    internal
    view
    override
    returns (IEarnStrategy.WithdrawalType[] memory types)
  {
    types = new IEarnStrategy.WithdrawalType[](_rewardTokens.length + 1);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    return _buildArraysWithRewards({ assetAmount: _connector_erc4626_balance() });
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxWithdraw()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    return _buildArraysWithRewards({ assetAmount: _connector_erc4626_maxWithdraw() });
  }

  function _emittedRewards(Rewards memory rewardsMem) private view returns (uint256) {
    uint256 emittedSinceLastUpdate = rewardsMem.lastUpdated < rewardsMem.deadline
      ? rewardsMem.emissionPerSecond * (Math.min(block.timestamp, rewardsMem.deadline) - rewardsMem.lastUpdated)
      : 0;
    return rewardsMem.emittedBeforeLastUpdate + emittedSinceLastUpdate;
  }

  // slither-disable-next-line dead-code
  function _emittedRewards(address rewardToken) private view returns (uint256) {
    return _emittedRewards(rewards[rewardToken]);
  }

  function _getRewardsManager() private view returns (address) {
    return globalRegistry().getAddressOrFail(MORPHO_REWARDS_MANAGER);
  }

  // slither-disable-next-line dead-code
  function _buildArraysWithRewards(uint256 assetAmount)
    private
    view
    returns (address[] memory tokens, uint256[] memory amounts)
  {
    address[] memory rewardsTokens = _rewardTokens;
    tokens = new address[](rewardsTokens.length + 1);
    amounts = new uint256[](tokens.length);
    tokens[0] = _connector_asset();
    amounts[0] = assetAmount;
    for (uint256 i = 0; i < rewardsTokens.length; ++i) {
      uint256 index = i + 1;
      tokens[index] = rewardsTokens[i];
      amounts[index] = _emittedRewards(rewardsTokens[i]);
    }
  }
}
