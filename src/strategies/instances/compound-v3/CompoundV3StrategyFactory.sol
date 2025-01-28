// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { CompoundV3Strategy, IGlobalEarnRegistry, ICERC20, ICometRewards } from "./CompoundV3Strategy.sol";

struct CompoundV3StrategyData {
  IEarnVault earnVault;
  IGlobalEarnRegistry globalRegistry;
  ICERC20 cToken;
  ICometRewards cometRewards;
  bytes creationValidationData;
  bytes guardianData;
  bytes feesData;
  bytes liquidityMiningData;
}

contract CompoundV3StrategyFactory is BaseStrategyFactory {
  constructor(CompoundV3Strategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(CompoundV3StrategyData calldata strategyData) external returns (CompoundV3Strategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = CompoundV3Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init({
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
  }

  function cloneStrategyAndRegister(
    address owner,
    CompoundV3StrategyData calldata strategyData
  )
    external
    returns (CompoundV3Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = CompoundV3Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister({
      owner: owner,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function cloneStrategyWithId(
    StrategyId strategyId,
    CompoundV3StrategyData calldata strategyData
  )
    external
    returns (CompoundV3Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = CompoundV3Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, strategyId);
    clone.initWithId({
      strategyId_: strategyId,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
  }

  function clone2Strategy(
    CompoundV3StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (CompoundV3Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = CompoundV3Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init({
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
  }

  function clone2StrategyAndRegister(
    address owner,
    CompoundV3StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (CompoundV3Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = CompoundV3Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister({
      owner: owner,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone2StrategyWithId(
    StrategyId strategyId,
    CompoundV3StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (CompoundV3Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData, salt);
    clone = CompoundV3Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, strategyId);
    clone.initWithId({
      strategyId_: strategyId,
      creationValidationData: strategyData.creationValidationData,
      guardianData: strategyData.guardianData,
      feesData: strategyData.feesData,
      liquidityMiningData: strategyData.liquidityMiningData
    });
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    ICERC20 cToken,
    ICometRewards cometRewards,
    bytes32 salt
  )
    external
    view
    returns (address clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, cToken, cometRewards);
    return _addressOfClone2(immutableData, salt);
  }

  function _calculateImmutableData(CompoundV3StrategyData calldata strategyData) internal view returns (bytes memory) {
    return _calculateImmutableData(
      strategyData.earnVault, strategyData.globalRegistry, strategyData.cToken, strategyData.cometRewards
    );
  }

  function _calculateImmutableData(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    ICERC20 cToken,
    ICometRewards cometRewards
  )
    internal
    view
    returns (bytes memory)
  {
    address asset = cToken.baseToken();
    return abi.encodePacked(earnVault, globalRegistry, asset, cToken, cometRewards);
  }
}
