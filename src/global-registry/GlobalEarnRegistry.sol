// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IGlobalEarnRegistry } from "../interfaces/IGlobalEarnRegistry.sol";

contract GlobalEarnRegistry is IGlobalEarnRegistry, Ownable2Step {
  struct InitialConfig {
    bytes32 id;
    address contractAddress;
  }

  /// @inheritdoc IGlobalEarnRegistry
  mapping(bytes32 id => address contractAddress) public getAddress;

  constructor(InitialConfig[] memory config, address owner_) Ownable(owner_) {
    for (uint256 i = 0; i < config.length; ++i) {
      _setAddress(config[i].id, config[i].contractAddress);
    }
  }

  /// @inheritdoc IGlobalEarnRegistry
  function getAddressOrFail(bytes32 id) external view returns (address) {
    address contractAddress = getAddress[id];
    if (contractAddress == address(0)) {
      revert AddressNotSet(id);
    }
    return contractAddress;
  }

  /// @inheritdoc IGlobalEarnRegistry
  function setAddress(bytes32 id, address contractAddress) external onlyOwner {
    _setAddress(id, contractAddress);
  }

  function _setAddress(bytes32 id, address contractAddress) internal {
    getAddress[id] = contractAddress;
    emit AddressSet(id, contractAddress);
  }
}
