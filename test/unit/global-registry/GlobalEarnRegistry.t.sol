// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

// solhint-disable no-unused-import
import { PRBTest } from "@prb/test/PRBTest.sol";
import { GlobalEarnRegistry, IGlobalEarnRegistry } from "src/global-registry/GlobalEarnRegistry.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract GlobalEarnRegistryTest is PRBTest {
  event AddressSet(bytes32 indexed id, address contractAddress);

  bytes32 private constant ID_1 = keccak256("id 1");
  bytes32 private constant ID_2 = keccak256("id 2");
  address private owner = address(1);
  address private initialAddress = address(10);

  GlobalEarnRegistry private globalRegistry;

  function setUp() public virtual {
    GlobalEarnRegistry.InitialConfig[] memory config = new GlobalEarnRegistry.InitialConfig[](1);
    config[0] = GlobalEarnRegistry.InitialConfig({ id: ID_2, contractAddress: initialAddress });
    vm.expectEmit();
    emit IGlobalEarnRegistry.AddressSet(ID_2, initialAddress);
    globalRegistry = new GlobalEarnRegistry(config, owner);
  }

  function test_constructor() public {
    assertEq(globalRegistry.getAddress(ID_2), initialAddress);
  }

  function test_getAddress_NotSet() public {
    assertEq(globalRegistry.getAddress(ID_1), address(0));
  }

  function test_getAddressOrFail_RevertWhen_NotSet() public {
    vm.expectRevert(abi.encodeWithSelector(IGlobalEarnRegistry.AddressNotSet.selector, ID_1));
    globalRegistry.getAddressOrFail(ID_1);
  }

  function test_setAddress_RevertWhen_CalledByNonOwner() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
    globalRegistry.setAddress(ID_1, address(1));
  }

  function test_setAddress() public {
    address newAddress = address(10);
    vm.prank(owner);
    vm.expectEmit();
    emit AddressSet(ID_1, newAddress);
    globalRegistry.setAddress(ID_1, newAddress);
    assertEq(globalRegistry.getAddress(ID_1), newAddress);
  }
}
