// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategyRegistry.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";

abstract contract BaseStrategyFactory {
  event StrategyCloned(IEarnBalmyStrategy clone, StrategyId strategyId);

  /// @notice The address for the implementation contract
  IEarnBalmyStrategy public immutable implementation;

  constructor(IEarnBalmyStrategy implementation_) {
    implementation = implementation_;
  }

  function _clone(bytes memory data) internal returns (IEarnBalmyStrategy clone) {
    clone = IEarnBalmyStrategy(Clones.cloneWithImmutableArgs(address(implementation), data, msg.value));
  }

  function _clone2(bytes memory data, bytes32 salt) internal returns (IEarnBalmyStrategy clone) {
    clone =
      IEarnBalmyStrategy(Clones.cloneDeterministicWithImmutableArgs(address(implementation), data, salt, msg.value));
  }

  function _addressOfClone2(bytes memory data, bytes32 salt) internal view returns (address clone) {
    return Clones.predictDeterministicAddressWithImmutableArgs(address(implementation), data, salt, address(this));
  }
}
