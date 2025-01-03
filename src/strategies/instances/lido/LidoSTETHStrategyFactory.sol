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
  bytes creationValidationData;
  bytes feesData;
  bytes liquidityMiningData;
  string description;
}

contract LidoSTETHStrategyFactory is BaseStrategyFactory {
  constructor(LidoSTETHStrategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(LidoSTETHStrategyData calldata strategyData) external returns (LidoSTETHStrategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init({
      creationValidationData: strategyData.creationValidationData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
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
    strategyId = clone.initAndRegister({
      owner: owner,
      creationValidationData: strategyData.creationValidationData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function cloneStrategyWithId(
    StrategyId strategyId,
    LidoSTETHStrategyData calldata strategyData
  )
    external
    returns (LidoSTETHStrategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, strategyId);
    clone.initWithId({
      strategyId_: strategyId,
      creationValidationData: strategyData.creationValidationData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
  }

  function clone2Strategy(
    LidoSTETHStrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (LidoSTETHStrategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init({
      creationValidationData: strategyData.creationValidationData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
  }

  function clone2StrategyAndRegister(
    address owner,
    LidoSTETHStrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (LidoSTETHStrategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    strategyId = clone.initAndRegister({
      owner: owner,
      creationValidationData: strategyData.creationValidationData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone2StrategyWithId(
    StrategyId strategyId,
    LidoSTETHStrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (LidoSTETHStrategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = LidoSTETHStrategy(payable(address(clone_)));
    emit StrategyCloned(clone, strategyId);
    clone.initWithId({
      strategyId_: strategyId,
      creationValidationData: strategyData.creationValidationData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData,
      description_: strategyData.description
    });
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IDelayedWithdrawalAdapter adapter,
    bytes32 salt
  )
    external
    view
    returns (address clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, adapter);
    return _addressOfClone2(immutableData, salt);
  }

  function _calculateImmutableData(LidoSTETHStrategyData calldata strategyData) internal pure returns (bytes memory) {
    return _calculateImmutableData(strategyData.earnVault, strategyData.globalRegistry, strategyData.adapter);
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
