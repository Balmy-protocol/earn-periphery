// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { StrategyId, IEarnStrategy, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategyRegistry.sol";
import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnVault.sol";

/**
 * @notice Interacting with strategies usually requires multiple steps because we need to figure out the strategy's
 *         address in order to call it. We could have its id, or we might have a position id instead. This contract
 *         aims to simplify this process by exposing a single function that will perform all the necessary steps.
 */
contract StrategyRouter {
  error StrategyNotFoundByStrategyId(IEarnStrategyRegistry registry, StrategyId strategyId);
  error StrategyNotFoundByPositionId(IEarnVault vault, uint256 positionId);

  function routeByStrategyId(
    IEarnStrategyRegistry registry,
    StrategyId strategyId,
    bytes calldata data
  )
    external
    payable
    returns (bytes memory result)
  {
    IEarnStrategy strategy = registry.getStrategy(strategyId);
    if (address(strategy) == address(0)) {
      revert StrategyNotFoundByStrategyId(registry, strategyId);
    }
    return Address.functionCallWithValue(address(strategy), data, msg.value);
  }

  function routeByPositionId(
    IEarnVault vault,
    uint256 positionId,
    bytes calldata data
  )
    external
    payable
    returns (bytes memory result)
  {
    (, IEarnStrategy strategy) = vault.positionsStrategy(positionId);
    if (address(strategy) == address(0)) {
      revert StrategyNotFoundByPositionId(vault, positionId);
    }
    return Address.functionCallWithValue(address(strategy), data, msg.value);
  }
}
