// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "../../BaseDeployPeriphery.sol";

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import {
  AaveV3StrategyFactory,
  AaveV3Strategy,
  IAaveV3Pool,
  IAaveV3Rewards,
  IAToken,
  AaveV3StrategyData
} from "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";
import { IEarnBalmyStrategy } from "src/interfaces/IEarnBalmyStrategy.sol";
import { StrategyId } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";

import { console2 } from "forge-std/console2.sol";

import { Fees } from "src/types/Fees.sol";

contract BaseDeployStrategies is BaseDeployPeriphery {
  function deployAaveV3Strategy(
    address aaveV3Pool,
    address aaveV3Rewards,
    IAToken aToken,
    bytes32 tosGroup,
    bytes32 signerGroup,
    address[] memory guardians,
    address[] memory judges,
    Fees memory fees,
    bytes32 guard
  )
    internal
    returns (IEarnBalmyStrategy strategy, StrategyId strategyId)
  {
    address implementation = deployContract("V1_S_AAVEV3", abi.encodePacked(type(AaveV3Strategy).creationCode));
    console2.log("Implementation deployed: ", implementation);
    AaveV3StrategyFactory aaveV3StrategyFactory = AaveV3StrategyFactory(
      deployContract(
        "V1_F_AAVEV3", abi.encodePacked(type(AaveV3StrategyFactory).creationCode, abi.encode(implementation))
      )
    );
    console2.log("Factory deployed: ", address(aaveV3StrategyFactory));
    address vault = getDeployedAddress("V1_VAULT");
    console2.log("Vault deployed: ", vault);
    address globalRegistry = getDeployedAddress("V1_GLOBAL_REGISTRY");
    console2.log("Global registry deployed: ", globalRegistry);

    bytes memory registryData = "";
    bytes memory manager1Data = tosGroup != bytes32(0) ? abi.encode(tosGroup) : bytes("");
    bytes memory manager2Data = signerGroup != bytes32(0) ? abi.encode(signerGroup) : bytes("");

    bytes[] memory validationManagersStrategyData = new bytes[](2);
    validationManagersStrategyData[0] = manager1Data;
    validationManagersStrategyData[1] = manager2Data;
    bytes memory creationValidationData = abi.encode(registryData, validationManagersStrategyData);
    bytes memory guardianData = guardians.length > 0 || judges.length > 0 ? abi.encode(guardians, judges) : bytes("");
    bytes memory liquidityMiningData = "";
    bytes memory feesData = fees.equals(DEFAULT_FEES) ? bytes("") : abi.encode(fees);
    bytes32 salt = keccak256(abi.encode("V1_S_AAVEV3", guard));

    address computedAddress = aaveV3StrategyFactory.addressOfClone2(
      IEarnVault(vault),
      IGlobalEarnRegistry(globalRegistry),
      aToken,
      IAaveV3Pool(aaveV3Pool),
      IAaveV3Rewards(aaveV3Rewards),
      salt
    );
    if (computedAddress.code.length > 0) {
      console2.log("Strategy already deployed", computedAddress);
    } else {
      (strategy, strategyId) = aaveV3StrategyFactory.clone2StrategyAndRegister(
        admin,
        AaveV3StrategyData(
          IEarnVault(vault),
          IGlobalEarnRegistry(globalRegistry),
          aToken,
          IAaveV3Pool(aaveV3Pool),
          IAaveV3Rewards(aaveV3Rewards),
          creationValidationData,
          guardianData,
          feesData,
          liquidityMiningData
        ),
        salt
      );

      console2.log("Strategy:", address(strategy));
      console2.log("Strategy ID:", StrategyId.unwrap(strategyId));
    }
  }
}
