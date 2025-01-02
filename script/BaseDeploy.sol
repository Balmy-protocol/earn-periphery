// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import { CreateXScript } from "createx-forge/script/CreateXScript.sol";

import "src/strategies/instances/aave-v3/AaveV3Strategy.sol";
import "src/strategies/instances/aave-v3/AaveV3StrategyFactory.sol";

import "src/strategies/instances/erc4626/ERC4626Strategy.sol";
import "src/strategies/instances/erc4626/ERC4626StrategyFactory.sol";

import "src/strategies/instances/lido/LidoSTETHStrategy.sol";
import "src/strategies/instances/lido/LidoSTETHStrategyFactory.sol";

contract BaseDeploy is Script, CreateXScript {
  uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
  address deployer = vm.envAddress("DEPLOYER");
  address admin = vm.envAddress("GOVERNOR");

  function setUp() public virtual withCreateX {
    //
    // `withCreateX` modifier checks there is a CreateX factory deployed
    // If not, etch it when running within a Forge testing environment (chainID = 31337)
    //
    // This sets `CreateX` for the scripting usage with functions:
    //      https://github.com/pcaversaccio/createx#available-versatile-functions
    //
    // WARNING - etching is not supported towards local explicit Anvil execution with default chainID
    //      This leads to a strange behaviour towards Anvil when Anvil does not have CreateX predeployed
    //      (seamingly correct transactions in the forge simulation even when broadcasted).
    //      Start Anvil with a different chainID, e.g. `anvil --chain-id 1982` to simulate a correct behaviour
    //      of missing CreateX.
    //
    // Behaviour towards external RPCs - this works as expected, i.e. continues if CreateX is deployed
    // and stops when not. (Tested with Tenderly devnets and BuildBear private testnets)
    //
  }

  function deployContract(bytes32 guard, bytes memory creationCode) public returns (address) {
    bytes32 salt = bytes32(abi.encodePacked(deployer, hex"00", guard));
    address computedAddress = computeCreate3Address(salt, deployer);
    if (computedAddress.code.length > 0) {
      console2.log("Contract already deployed at", computedAddress);
      return computedAddress;
    }
    address deployedAddress = create3(salt, creationCode);
    //console2.log("Deployed address:", deployedAddress);
    require(computedAddress == deployedAddress, "Computed and deployed address do not match!");
    return deployedAddress;
  }

  function getDeployedAddress(bytes32 guard) public view returns (address) {
    bytes32 salt = bytes32(abi.encodePacked(deployer, hex"00", guard));
    address computedAddress = computeCreate3Address(salt, deployer);
    require(computedAddress.code.length > 0, "Contract not deployed!");
    return computedAddress;
  }
}
