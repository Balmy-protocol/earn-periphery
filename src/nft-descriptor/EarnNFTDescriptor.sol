// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnNFTDescriptor } from "../interfaces/IEarnNFTDescriptor.sol";
import { IEarnVault } from "../interfaces/IEarnVault.sol";

/// @title Describes NFT token positions
/// @notice Produces a string containing the data URI for a JSON metadata string
contract EarnNFTDescriptor is IEarnNFTDescriptor {
  // TODO: NFT descriptions needs to be updatable somehow
  // TODO: define data to return
  /// @inheritdoc IEarnNFTDescriptor
  function tokenURI(IEarnVault, uint256) external pure returns (string memory) {
    return "";
  }
}
