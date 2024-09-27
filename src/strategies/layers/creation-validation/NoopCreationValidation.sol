// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { BaseCreationValidation } from "./base/BaseCreationValidation.sol";

abstract contract NoopCreationValidation is BaseCreationValidation {
  // slither-disable-start naming-convention,dead-code
  // solhint-disable-next-line no-empty-blocks
  function _creationValidation_validate(address, bytes calldata) internal view override {
    // Do nothing
  }
  // slither-disable-end naming-convention,dead-code
}
