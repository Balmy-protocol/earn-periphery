// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { ClonesWithImmutableArgs } from "@clones/ClonesWithImmutableArgs.sol";
import { IEarnStrategyRegistry, StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategyRegistry.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";

abstract contract BaseStrategyFactory {
  using ClonesWithImmutableArgs for address;

  event StrategyCloned(IEarnBalmyStrategy clone, StrategyId strategyId);

  /// @notice The address for the implementation contract
  IEarnBalmyStrategy public immutable implementation;

  constructor(IEarnBalmyStrategy implementation_) {
    implementation = implementation_;
  }

  function _clone(bytes memory data) internal returns (IEarnBalmyStrategy clone) {
    clone = IEarnBalmyStrategy(address(implementation).clone(data, msg.value));
  }

  function _clone2(bytes memory data) internal returns (IEarnBalmyStrategy clone) {
    clone = IEarnBalmyStrategy(address(implementation).clone2(data, msg.value));
  }

  function _clone3(bytes memory data, bytes32 salt) internal returns (IEarnBalmyStrategy clone) {
    clone = IEarnBalmyStrategy(address(implementation).clone3(data, salt, msg.value));
  }

  function _addressOfClone2(bytes memory data) internal view returns (address clone) {
    return address(implementation).addressOfClone2(data);
  }

  function addressOfClone3(bytes32 salt) external view returns (address) {
    return ClonesWithImmutableArgs.addressOfClone3(salt);
  }
}
