// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { LidoSTETHStrategy, IGlobalEarnRegistry, IDelayedWithdrawalAdapter } from "./LidoSTETHStrategy.sol";

struct LidoSTETHStrategyData {
  IEarnVault earnVault;
  IGlobalEarnRegistry globalRegistry;
  IDelayedWithdrawalAdapter adapter;
  bytes tosData;
  bytes feesData;
  string description;
}

contract LidoSTETHStrategyFactory is BaseStrategyFactory {
  constructor(LidoSTETHStrategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(LidoSTETHStrategyData calldata strategyData) external returns (LidoSTETHStrategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.feesData, strategyData.description);
  }

  function cloneStrategyAndRegister(
    address owner,
    LidoSTETHStrategyData calldata strategyData
  )
    external
    returns (LidoSTETHStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(owner, strategyData.tosData, strategyData.feesData, strategyData.description);
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone2Strategy(LidoSTETHStrategyData calldata strategyData) external returns (LidoSTETHStrategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.feesData, strategyData.description);
  }

  function clone2StrategyAndRegister(
    address owner,
    LidoSTETHStrategyData calldata strategyData
  )
    external
    returns (LidoSTETHStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(owner, strategyData.tosData, strategyData.feesData, strategyData.description);
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone3Strategy(
    LidoSTETHStrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (LidoSTETHStrategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    (IEarnBalmyStrategy clone_) = _clone3(immutableData, salt);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.feesData, strategyData.description);
  }

  function clone3StrategyAndRegister(
    address owner,
    LidoSTETHStrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (LidoSTETHStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    (IEarnBalmyStrategy clone_) = _clone3(immutableData, salt);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(owner, strategyData.tosData, strategyData.feesData, strategyData.description);
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IDelayedWithdrawalAdapter adapter
  )
    external
    view
    returns (address clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, adapter);
    return _addressOfClone2(immutableData);
  }

  function _calculateImmutableData(LidoSTETHStrategyData calldata strategyImmutableData)
    internal
    pure
    returns (bytes memory)
  {
    return _calculateImmutableData(
      strategyImmutableData.earnVault, strategyImmutableData.globalRegistry, strategyImmutableData.adapter
    );
  }

  function _calculateImmutableData(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IDelayedWithdrawalAdapter adapter
  )
    internal
    pure
    returns (bytes memory)
  {
    return abi.encodePacked(earnVault, globalRegistry, adapter);
  }
}
