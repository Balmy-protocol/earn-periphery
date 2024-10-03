// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { BaseCreationValidation } from "./base/BaseCreationValidation.sol";

abstract contract TOSCreationValidation is BaseCreationValidation, AccessControl, Initializable {
  /**
   * @notice Emitted when the TOS is updated
   * @param tos The new TOS
   * @param sender The address that updated the TOS
   */
  event TOSUpdated(bytes tos, address sender);

  /// @notice Emitted when an invalid TOS signature is provided
  error InvalidTOSSignature();

  using MessageHashUtils for bytes;

  /// @notice The role that allows updating the TOS
  bytes32 public constant TOS_UPDATE_ROLE = keccak256("TOS_UPDATE_ROLE");

  /// @notice The hash of the current TOS
  bytes32 public tosHash;

  // slither-disable-next-line naming-convention,dead-code
  function _creationValidation_init(bytes memory tos, address[] memory admins) internal onlyInitializing {
    _setTOS(tos);
    for (uint256 i; i < admins.length; ++i) {
      _grantRole(TOS_UPDATE_ROLE, admins[i]);
    }
  }

  /**
   * @notice Updates the TOS
   * @dev Can only be called by someone with the TOS_UPDATE_ROLE
   * @param tos The new TOS to set
   */
  function setTOS(bytes calldata tos) external onlyRole(TOS_UPDATE_ROLE) {
    _setTOS(tos);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _creationValidation_validate(address sender, bytes calldata signature) internal view override {
    bytes32 _tosHash = tosHash;
    if (_tosHash != bytes32(0) && !SignatureChecker.isValidSignatureNow(sender, _tosHash, signature)) {
      revert InvalidTOSSignature();
    }
  }

  function _setTOS(bytes memory tos) private {
    tosHash = tos.length == 0 ? bytes32(0) : tos.toEthSignedMessageHash();
    emit TOSUpdated(tos, msg.sender);
  }
}
