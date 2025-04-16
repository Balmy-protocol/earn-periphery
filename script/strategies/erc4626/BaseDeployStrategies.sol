// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { BaseDeployPeriphery } from "../../BaseDeployPeriphery.sol";

import { IEarnVault } from "@balmy/earn-core/interfaces/IEarnVault.sol";
import { IGlobalEarnRegistry } from "src/interfaces/IGlobalEarnRegistry.sol";
import {
  ERC4626StrategyFactory,
  ERC4626Strategy,
  ERC4626StrategyData,
  IERC4626
} from "src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";
import { IEarnBalmyStrategy } from "src/interfaces/IEarnBalmyStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";

import { console2 } from "forge-std/console2.sol";

import { Fees } from "src/types/Fees.sol";

contract BaseDeployStrategies is BaseDeployPeriphery {
  function deployERC4626Strategy(
    IERC4626 erc4626Vault,
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
    return deployERC4626StrategyWithId(
      erc4626Vault, tosGroup, signerGroup, guardians, judges, fees, guard, description, StrategyIdConstants.NO_STRATEGY
    );
  }

  function deployERC4626StrategyWithId(
    IERC4626 erc4626Vault,
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
    address implementation = deployContract("V5_S_ERC4626", abi.encodePacked(type(ERC4626Strategy).creationCode));
    console2.log("Implementation deployed: ", implementation);
    ERC4626StrategyFactory erc4626StrategyFactory = ERC4626StrategyFactory(
      deployContract(
        "V5_F_ERC4626", abi.encodePacked(type(ERC4626StrategyFactory).creationCode, abi.encode(implementation))
      )
    );
    console2.log("Factory deployed: ", address(erc4626StrategyFactory));
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
    bytes32 salt = keccak256(abi.encode("V5_S_ERC4626", guard));

    address computedAddress =
      erc4626StrategyFactory.addressOfClone2(IEarnVault(vault), IGlobalEarnRegistry(globalRegistry), erc4626Vault, salt);
    if (computedAddress.code.length > 0) {
      console2.log("Strategy already deployed", computedAddress);
    } else {
      if (initialStrategyId == StrategyIdConstants.NO_STRATEGY) {
        (strategy, strategyId) = erc4626StrategyFactory.clone2StrategyAndRegister(
          admin,
          ERC4626StrategyData(
            IEarnVault(vault),
            IGlobalEarnRegistry(globalRegistry),
            erc4626Vault,
            creationValidationData,
            guardianData,
            feesData,
            liquidityMiningData
          ),
          salt
        );
      } else {
        strategyId = initialStrategyId;
        strategy = erc4626StrategyFactory.clone2StrategyWithId(
          StrategyId(initialStrategyId),
          ERC4626StrategyData(
            IEarnVault(vault),
            IGlobalEarnRegistry(globalRegistry),
            erc4626Vault,
            creationValidationData,
            guardianData,
            feesData,
            liquidityMiningData
          ),
          salt
        );
      }
      console2.log(string.concat(description, ":"), address(strategy));
      console2.log(string.concat(description, " id:"), StrategyId.unwrap(strategyId));
    }
  }
}
