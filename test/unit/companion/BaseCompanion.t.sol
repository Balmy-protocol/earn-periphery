// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Test } from "forge-std/Test.sol";
import { BaseCompanion, IPermit2 } from "src/companion/BaseCompanion.sol";

contract BaseCompanionTest is Test {
  BaseCompanionInstance private companion;
  Swapper private swapper;
  address private owner = address(1);
  IPermit2 private permit2 = new Permit2();

  function setUp() public virtual {
    swapper = new Swapper();
    companion = new BaseCompanionInstance(address(swapper), address(swapper), owner, permit2);
  }

  function test_constructor() public {
    assertEq(companion.swapper(), address(swapper));
    assertEq(companion.allowanceTarget(), address(swapper));
    assertEq(companion.owner(), owner);
    assertEq(address(companion.PERMIT2()), address(permit2));
    assertEq(companion.NATIVE_TOKEN(), address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));
  }
}

contract BaseCompanionInstance is BaseCompanion {
  constructor(
    address swapper_,
    address allowanceTarget_,
    address owner_,
    IPermit2 permit2
  )
    BaseCompanion(swapper_, allowanceTarget_, owner_, permit2)
  { }
}

contract Swapper {
  // solhint-disable no-empty-blocks
  function swap(address tokenIn, address tokenOut) external payable { }
}

contract Permit2 is IPermit2 {
  // solhint-disable no-empty-blocks
  function DOMAIN_SEPARATOR() external view override returns (bytes32) { }

  // solhint-disable no-empty-blocks
  function permitTransferFrom(
    PermitTransferFrom calldata permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes calldata signature
  )
    external
    override
  { }

  // solhint-disable no-empty-blocks
  function permitTransferFrom(
    PermitBatchTransferFrom memory permit,
    SignatureTransferDetails[] calldata transferDetails,
    address owner,
    bytes calldata signature
  )
    external
    override
  { }
}
