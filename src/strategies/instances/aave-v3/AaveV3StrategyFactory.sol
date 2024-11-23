// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { AaveV3Strategy, IGlobalEarnRegistry, IAToken, IAaveV3Pool, IAaveV3Rewards } from "./AaveV3Strategy.sol";

struct AaveV3StrategyData {
  IEarnVault earnVault;
  IGlobalEarnRegistry globalRegistry;
  IAToken aToken;
  IAaveV3Pool aaveV3Pool;
  IAaveV3Rewards aaveV3Rewards;
  bytes tosData;
  bytes guardianData;
  bytes feesData;
  string description;
}

contract AaveV3StrategyFactory is BaseStrategyFactory {
  constructor(AaveV3Strategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(AaveV3StrategyData calldata strategyData) external returns (AaveV3Strategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = AaveV3Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description);
  }

  function cloneStrategyAndRegister(
    address owner,
    AaveV3StrategyData calldata strategyData
  )
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(
      owner, strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description
    );
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone2Strategy(AaveV3StrategyData calldata strategyData) external returns (AaveV3Strategy clone) {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData);
    clone = AaveV3Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description);
  }

  function clone2StrategyAndRegister(
    address owner,
    AaveV3StrategyData calldata strategyData
  )
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    IEarnBalmyStrategy clone_ = _clone2(immutableData);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(
      owner, strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description
    );
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function clone3Strategy(
    AaveV3StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (AaveV3Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    (IEarnBalmyStrategy clone_) = _clone3(immutableData, salt);
    clone = AaveV3Strategy(payable(address(clone_)));
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
    clone.init(strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description);
  }

  function clone3StrategyAndRegister(
    address owner,
    AaveV3StrategyData calldata strategyData,
    bytes32 salt
  )
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(strategyData);
    (IEarnBalmyStrategy clone_) = _clone3(immutableData, salt);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(
      owner, strategyData.tosData, strategyData.guardianData, strategyData.feesData, strategyData.description
    );
    // slither-disable-next-line reentrancy-events
    emit StrategyCloned(clone, strategyId);
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IAToken aToken,
    IAaveV3Pool aaveV3Pool,
    IAaveV3Rewards aaveV3Rewards
  )
    external
    view
    returns (address clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, aToken, aaveV3Pool, aaveV3Rewards);
    return _addressOfClone2(immutableData);
  }

  function _calculateImmutableData(AaveV3StrategyData calldata strategyImmutableData)
    internal
    view
    returns (bytes memory)
  {
    return _calculateImmutableData(
      strategyImmutableData.earnVault,
      strategyImmutableData.globalRegistry,
      strategyImmutableData.aToken,
      strategyImmutableData.aaveV3Pool,
      strategyImmutableData.aaveV3Rewards
    );
  }

  function _calculateImmutableData(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IAToken aToken,
    IAaveV3Pool aaveV3Pool,
    IAaveV3Rewards aaveV3Rewards
  )
    internal
    view
    returns (bytes memory)
  {
    address asset = aToken.UNDERLYING_ASSET_ADDRESS();
    return abi.encodePacked(earnVault, globalRegistry, aToken, asset, aaveV3Pool, aaveV3Rewards);
  }
}
