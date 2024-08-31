// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IGlobalEarnRegistry } from "../interfaces/IGlobalEarnRegistry.sol";

contract GlobalEarnRegistry is IGlobalEarnRegistry, Ownable2Step {
  mapping(bytes32 id => address contractAddress) private _addresses;

  constructor(address owner_) Ownable(owner_) { }

  function getAddress(bytes32 id) external view returns (address) {
    address contractAddress = _addresses[id];
    if (contractAddress == address(0)) {
      revert AddressNotSet(id);
    }
    return contractAddress;
  }

  function setAddress(bytes32 id, address contractAddress) external onlyOwner {
    _addresses[id] = contractAddress;
    emit AddressSet(id, contractAddress);
  }
}
