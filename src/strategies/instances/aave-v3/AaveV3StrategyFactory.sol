// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { StrategyId, IEarnVault, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { AaveV3Strategy, IGlobalEarnRegistry, IAToken, IAaveV3Pool, IAaveV3Rewards } from "./AaveV3Strategy.sol";

struct AaveV3StrategyImmutableData {
  IEarnStrategyRegistry strategyRegistry;
  address owner;
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

  function cloneAndRegister(AaveV3StrategyImmutableData calldata strategyImmutableData)
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    address asset = strategyImmutableData.aToken.UNDERLYING_ASSET_ADDRESS();
    bytes memory immutableData = abi.encodePacked(
      strategyImmutableData.earnVault,
      strategyImmutableData.globalRegistry,
      strategyImmutableData.aToken,
      asset,
      strategyImmutableData.aaveV3Pool,
      strategyImmutableData.aaveV3Rewards
    );
    (IEarnBalmyStrategy clone_, StrategyId stratId) =
      _cloneAndRegister(strategyImmutableData.strategyRegistry, strategyImmutableData.owner, immutableData);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(
      strategyImmutableData.tosData,
      strategyImmutableData.guardianData,
      strategyImmutableData.feesData,
      strategyImmutableData.description
    );
  }

  function clone2AndRegister(AaveV3StrategyImmutableData calldata strategyImmutableData)
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    address asset = strategyImmutableData.aToken.UNDERLYING_ASSET_ADDRESS();
    bytes memory immutableData = abi.encodePacked(
      strategyImmutableData.earnVault,
      strategyImmutableData.globalRegistry,
      strategyImmutableData.aToken,
      asset,
      strategyImmutableData.aaveV3Pool,
      strategyImmutableData.aaveV3Rewards
    );
    (IEarnBalmyStrategy clone_, StrategyId stratId) =
      _clone2AndRegister(strategyImmutableData.strategyRegistry, strategyImmutableData.owner, immutableData);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(
      strategyImmutableData.tosData,
      strategyImmutableData.guardianData,
      strategyImmutableData.feesData,
      strategyImmutableData.description
    );
  }

  function clone3AndRegister(
    AaveV3StrategyImmutableData calldata strategyImmutableData,
    bytes32 salt
  )
    external
    returns (AaveV3Strategy clone, StrategyId strategyId)
  {
    address asset = strategyImmutableData.aToken.UNDERLYING_ASSET_ADDRESS();
    bytes memory immutableData = abi.encodePacked(
      strategyImmutableData.earnVault,
      strategyImmutableData.globalRegistry,
      strategyImmutableData.aToken,
      asset,
      strategyImmutableData.aaveV3Pool,
      strategyImmutableData.aaveV3Rewards
    );
    (IEarnBalmyStrategy clone_, StrategyId stratId) =
      _clone3AndRegister(strategyImmutableData.strategyRegistry, strategyImmutableData.owner, immutableData, salt);
    clone = AaveV3Strategy(payable(address(clone_)));
    strategyId = stratId;
    clone.init(
      strategyImmutableData.tosData,
      strategyImmutableData.guardianData,
      strategyImmutableData.feesData,
      strategyImmutableData.description
    );
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IAToken aToken,
    IAaveV3Pool aaveV3Pool,
    IAaveV3Rewards aaveV3Rewards
  )
    external
    returns (address clone)
  {
    address asset = aToken.UNDERLYING_ASSET_ADDRESS();
    bytes memory data = abi.encodePacked(earnVault, globalRegistry, aToken, asset, aaveV3Pool, aaveV3Rewards);
    return _addressOfClone2(data);
  }
}
