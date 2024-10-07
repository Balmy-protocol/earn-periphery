// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { AaveV2Connector, IERC20, IAaveV2Pool, IAToken } from "src/strategies/layers/connector/AaveV2Connector.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorTest.t.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";

contract AaveV2ConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  IAToken internal aAaveV2Vault = IAToken(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e); // aWETH
  IERC20 internal aAaveV2Asset = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH
  IAaveV2Pool internal aAaveV2Pool = IAaveV2Pool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9); // Aave V2 LendingPool

  // We need a holder for the aToken token
  address internal constant AAVE_V2_VAULT_HOLDER = 0xeb43b5597E3bDe0b0C03eE6731bA7c0247E1581E; // aWETH holder

  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _configureFork() internal override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);
    vm.rollFork(20_478_227);
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new AaveV2ConnectorInstance(aAaveV2Vault, aAaveV2Asset, aAaveV2Pool);
  }

  function _farmToken() internal view virtual override returns (address) {
    return address(aAaveV2Vault);
  }

  function _setBalance(address asset, address account, uint256 amount) internal override {
    if (asset == address(aAaveV2Vault)) {
      // We need to set the balance of the account to 0
      uint256 balance = IERC20(asset).balanceOf(account);
      if (balance > amount) {
        vm.prank(account);
        IERC20(asset).transfer(AAVE_V2_VAULT_HOLDER, balance - amount);
      } else if (balance < amount) {
        vm.prank(AAVE_V2_VAULT_HOLDER);
        IERC20(asset).transfer(account, amount - balance);
      }
    } else {
      return super._setBalance(asset, account, amount);
    }
  }
}

contract AaveV2ConnectorInstance is BaseConnectorInstance, AaveV2Connector {
  IAToken internal immutable _vault;
  IERC20 internal immutable _vaultAsset;
  IAaveV2Pool internal immutable _pool;

  constructor(IAToken __vault, IERC20 __asset, IAaveV2Pool __pool) initializer {
    _vault = __vault;
    _vaultAsset = __asset;
    _pool = __pool;
    _connector_init();
  }

  function pool() public view override returns (IAaveV2Pool) {
    return _pool;
  }

  function aToken() public view override returns (IAToken) {
    return _vault;
  }

  function _asset() internal view override returns (IERC20) {
    return _vaultAsset;
  }
}
