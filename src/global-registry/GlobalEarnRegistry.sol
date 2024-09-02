// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IGlobalEarnRegistry } from "../interfaces/IGlobalEarnRegistry.sol";

contract GlobalEarnRegistry is IGlobalEarnRegistry, Ownable2Step {
  mapping(bytes32 id => address contractAddress) public getAddress;

  constructor(address owner_) Ownable(owner_) { }

  function getAddressOrFail(bytes32 id) external view returns (address) {
    address contractAddress = getAddress[id];
    if (contractAddress == address(0)) {
      revert AddressNotSet(id);
    }
    return contractAddress;
  }

  function setAddress(bytes32 id, address contractAddress) external onlyOwner {
    getAddress[id] = contractAddress;
    emit AddressSet(id, contractAddress);
  }
}
