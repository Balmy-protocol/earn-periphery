// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "../../BaseDeployPeriphery.sol";

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import {
  CompoundV3StrategyFactory,
  CompoundV3Strategy,
  ICERC20,
  ICometRewards,
  CompoundV3StrategyData
} from "src/strategies/instances/compound-v3/CompoundV3StrategyFactory.sol";
import { IEarnBalmyStrategy } from "src/interfaces/IEarnBalmyStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { console2 } from "forge-std/console2.sol";

import { Fees } from "src/types/Fees.sol";

contract BaseDeployStrategies is BaseDeployPeriphery {
  function deployCompoundV3Strategy(
    ICERC20 cToken,
    address cometRewards,
    bytes32 tosGroup,
    bytes32 signerGroup,
    address[] memory guardians,
    address[] memory judges,
    Fees memory fees,
    bytes32 guard,
    string memory description
  )
    internal
    returns (IEarnBalmyStrategy strategy, StrategyId strategyId)
  {
    return deployCompoundV3StrategyWithId(
      cToken,
      cometRewards,
      tosGroup,
      signerGroup,
      guardians,
      judges,
      fees,
      guard,
      description,
      StrategyIdConstants.NO_STRATEGY
    );
  }

  function deployCompoundV3StrategyWithId(
    ICERC20 cToken,
    address cometRewards,
    bytes32 tosGroup,
    bytes32 signerGroup,
    address[] memory guardians,
    address[] memory judges,
    Fees memory fees,
    bytes32 guard,
    string memory description,
    StrategyId initialStrategyId
  )
    internal
    returns (IEarnBalmyStrategy strategy, StrategyId strategyId)
  {
    address implementation = deployContract("V6_S_COMPV3", abi.encodePacked(type(CompoundV3Strategy).creationCode));
    console2.log("Implementation deployed: ", implementation);
    CompoundV3StrategyFactory compoundV3StrategyFactory = CompoundV3StrategyFactory(
      deployContract(
        "V6_F_COMPV3", abi.encodePacked(type(CompoundV3StrategyFactory).creationCode, abi.encode(implementation))
      )
    );
    console2.log("Factory deployed: ", address(compoundV3StrategyFactory));
    address vault = getDeployedAddress("V2_VAULT");
    console2.log("Vault deployed: ", vault);
    address globalRegistry = getDeployedAddress("V2_GLOBAL_REGISTRY");
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
    bytes32 salt = keccak256(abi.encode("V1_S_COMPV3", guard));

    address computedAddress = compoundV3StrategyFactory.addressOfClone2(
      IEarnVault(vault), IGlobalEarnRegistry(globalRegistry), cToken, ICometRewards(cometRewards), salt
    );
    if (computedAddress.code.length > 0) {
      console2.log("\u001b[93m\u2718 Strategy already deployed at:", computedAddress, "\u001b[0m");
    } else {
      if (initialStrategyId == StrategyIdConstants.NO_STRATEGY) {
        (strategy, strategyId) = compoundV3StrategyFactory.clone2StrategyAndRegister(
          admin,
          CompoundV3StrategyData(
            IEarnVault(vault),
            IGlobalEarnRegistry(globalRegistry),
            cToken,
            ICometRewards(cometRewards),
            creationValidationData,
            guardianData,
            feesData,
            liquidityMiningData
          ),
          salt
        );
      } else {
        strategy = compoundV3StrategyFactory.clone2StrategyWithId(
          StrategyId(initialStrategyId),
          CompoundV3StrategyData(
            IEarnVault(vault),
            IGlobalEarnRegistry(globalRegistry),
            cToken,
            ICometRewards(cometRewards),
            creationValidationData,
            guardianData,
            feesData,
            liquidityMiningData
          ),
          salt
        );
      }
      console2.log("\u001b[92m\u2714", string.concat(description, ":"), address(strategy), "\u001b[0m");
      console2.log("\u001b[92m\u2714", string.concat(description, " id:"), StrategyId.unwrap(strategyId), "\u001b[0m");
    }
  }
}
