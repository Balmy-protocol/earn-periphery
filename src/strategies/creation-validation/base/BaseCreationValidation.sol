// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

abstract contract BaseCreationValidation {
  // slither-disable-next-line naming-convention
  function _creationValidation_validate(address, bytes calldata) internal virtual;
}
