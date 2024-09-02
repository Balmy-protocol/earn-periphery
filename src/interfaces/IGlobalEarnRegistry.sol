// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8;

interface IGlobalEarnRegistry {
  /**
   * @notice Emitted when a contract address is set
   * @param id The id of the contract
   * @param contractAddress The address of the contract
   */
  event AddressSet(bytes32 indexed id, address contractAddress);

  /// @notice Thrown when trying to get an address that has not been set
  error AddressNotSet(bytes32 id);

  /**
   * @notice Returns the address of the contract with the given id
   * @param id The id of the contract
   * @return The address of the contract (or zero address if not set)
   */
  function getAddress(bytes32 id) external view returns (address);

  /**
   * @notice Returns the address of the contract with the given id
   * @dev Will revert if the contract has not been registered
   * @param id The id of the contract
   * @return The address of the contract
   */
  function getAddressOrFail(bytes32 id) external view returns (address);

  /**
   * @notice Sets the address of the contract with the given id
   * @dev Can only be called by the owner
   * @param id The id of the contract
   * @param contractAddress The address of the contract. Can be set to zero to clear the id
   */
  function setAddress(bytes32 id, address contractAddress) external;
}
