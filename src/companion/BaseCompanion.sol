// SPDX-License-Identifier: TBD
pragma solidity >=0.8.22;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IPermit2 } from "../interfaces/external/IPermit2.sol";

/**
 * @notice This contract will work as base companion for all our contracts. It will extend the capabilities of our
 *         companion contracts so that they can execute multicalls, swaps, and more
 * @dev All public functions are payable, so that they can be multicalled together with other payable functions when
 *      msg.value > 0
 */
abstract contract BaseCompanion is Ownable2Step {
  using SafeERC20 for IERC20;
  using Address for address;
  using Address for address payable;

  /// @notice The address used to represent the native token
  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  /// @notice Returns the address of the Permit2 contract
  // slither-disable-start naming-convention
  // solhint-disable-next-line var-name-mixedcase
  IPermit2 public immutable PERMIT2;
  // slither-disable-end naming-convention

  /// @notice The address of the swapper
  // slither-disable-next-line immutable-states TODO: remove once used
  address public swapper;

  /// @notice The address of the allowance target
  // slither-disable-next-line immutable-states TODO: remove once used
  address public allowanceTarget;

  constructor(address swapper_, address allowanceTarget_, address owner_, IPermit2 permit2) Ownable(owner_) {
    swapper = swapper_;
    allowanceTarget = allowanceTarget_;
    PERMIT2 = permit2;
  }

  // slither-disable-next-line locked-ether TODO: remove once send function is added
  receive() external payable { }

  /**
   * @notice Returns the contract's balance of the given token
   * @dev We are making this public because it could help with simulations
   * @param token The token to check
   * @return The balance of the token
   */
  function balanceOf(address token) public view returns (uint256) {
    return token == NATIVE_TOKEN ? address(this).balance : IERC20(token).balanceOf(address(this));
  }

  ////////////////////////////////////////////////////////////////////////
  ///////////////////////////// TAKE FUNCTIONS ///////////////////////////
  ////////////////////////////////////////////////////////////////////////

  /**
   * @notice Takes the given amount of tokens from the caller and transfers it to the recipient
   * @param token The token to take
   * @param amount The amount to take
   * @param recipient The transfer's recipient
   */
  function takeFromCaller(IERC20 token, uint256 amount, address recipient) external payable {
    token.safeTransferFrom(msg.sender, recipient, amount);
  }

  /**
   * @notice Takes the given amount of tokens from the caller with Permit2 and transfers it to the recipient
   * @param token The token to take
   * @param amount The amount to take
   * @param nonce The signed nonce
   * @param deadline The signature's deadline
   * @param signature The owner's signature
   * @param recipient The address that will receive the funds
   */
  function permitTakeFromCaller(
    address token,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature,
    address recipient
  )
    external
    payable
  {
    PERMIT2.permitTransferFrom(
      IPermit2.PermitTransferFrom({
        permitted: IPermit2.TokenPermissions({ token: token, amount: amount }),
        nonce: nonce,
        deadline: deadline
      }),
      IPermit2.SignatureTransferDetails({ to: recipient, requestedAmount: amount }),
      msg.sender,
      signature
    );
  }

  /**
   * @notice Takes the a batch of tokens from the caller with Permit2 and transfers it to the recipient
   * @param tokens The tokens to take
   * @param nonce The signed nonce
   * @param deadline The signature's deadline
   * @param signature The owner's signature
   * @param recipient The address that will receive the funds
   */
  function batchPermitTakeFromCaller(
    IPermit2.TokenPermissions[] calldata tokens,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature,
    address recipient
  )
    external
    payable
  {
    IPermit2.SignatureTransferDetails[] memory details = new IPermit2.SignatureTransferDetails[](tokens.length);
    for (uint256 i; i < details.length; ++i) {
      details[i] = IPermit2.SignatureTransferDetails({ to: recipient, requestedAmount: tokens[i].amount });
    }

    PERMIT2.permitTransferFrom(
      IPermit2.PermitBatchTransferFrom({ permitted: tokens, nonce: nonce, deadline: deadline }),
      details,
      msg.sender,
      signature
    );
  }
}
