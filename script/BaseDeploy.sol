// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { CreateXScript } from "createx-forge/script/CreateXScript.sol";
import { console2 } from "forge-std/console2.sol";

contract BaseDeploy is CreateXScript {
  address internal admin = vm.envAddress("GOVERNOR");
  address internal deployer = vm.envAddress("DEPLOYER");

  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal SIGNER_GROUP = keccak256("signer_group");
  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal TOS_GROUP = keccak256("guardian_tos");

  // solhint-disable-next-line no-empty-blocks
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
    // solhint-disable-next-line reason-string
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
