// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC4626, ERC4626Connector, IERC20 } from "src/strategies/layers/connector/ERC4626Connector.sol";
import { BaseConnectorInstance } from "./base/BaseConnectorTest.t.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";

contract ERC4626ConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  // solhint-disable-next-line const-name-snakecase
  IERC4626 internal constant sDAI = IERC4626(0x83F20F44975D03b1b09e64809B757c47f942BEeA);

  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _configureFork() internal override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);
    vm.rollFork(20_000_000);
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new ERC4626ConnectorInstance(sDAI);
  }

  function _farmToken() internal pure override returns (address) {
    return address(sDAI);
  }
}

contract ERC4626ConnectorInstance is BaseConnectorInstance, ERC4626Connector {
  IERC4626 internal immutable _vault;

  constructor(IERC4626 __vault) initializer {
    _vault = __vault;
    _connector_init();
  }

  function ERC4626Vault() public view override returns (IERC4626) {
    return _vault;
  }

  function _asset() internal view override returns (IERC20) {
    return IERC20(_vault.asset());
  }
}
