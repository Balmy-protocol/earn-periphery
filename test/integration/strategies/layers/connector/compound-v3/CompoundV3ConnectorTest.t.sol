// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import {
  CompoundV3Connector,
  IERC20,
  ICERC20,
  ICometRewards
} from "src/strategies/layers/connector/compound-v3/CompoundV3Connector.sol";
import { BaseConnectorInstance } from "../base/BaseConnectorInstance.sol";
import { BaseConnectorImmediateWithdrawalTest } from "../base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "../base/BaseConnectorFarmTokenTest.t.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";

abstract contract CompoundV3ConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _asset() internal view virtual returns (address);
  function _cometRewards() internal view virtual returns (ICometRewards);
  function _cToken() internal view virtual returns (ICERC20);
  function _cTokenHolder() internal view virtual returns (address);

  function _configureFork() internal override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("polygon"));
    vm.selectFork(mainnetFork);

    vm.rollFork(65_355_051);
    vm.makePersistent(address(_farmToken())); // We need to make the farm token persistent for the next roll fork
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new CompoundV3ConnectorInstance(_cToken(), _asset(), _cometRewards());
  }

  function _farmToken() internal view virtual override returns (address) {
    return address(_cToken());
  }

  function _generateYield() internal virtual override {
    //_setBalance(address(_comp()), address(cometRewardsMock), 1e13);
    //cometRewardsMock._generateYield(1e3);
  }

  function _setBalance(address asset, address account, uint256 amount) internal override {
    if (asset == address(_cToken())) {
      // We need to set the balance of the account to 0
      uint256 balance = IERC20(asset).balanceOf(account);
      if (balance > amount) {
        vm.prank(account);
        IERC20(asset).transfer(_cTokenHolder(), balance - amount);
      } else if (balance < amount) {
        vm.prank(_cTokenHolder());
        IERC20(asset).transfer(account, amount - balance);
      }
    } else {
      return super._setBalance(asset, account, amount);
    }
  }

  function _connectorBalanceOfFarmToken() internal pure virtual override returns (uint256) {
    return 1e10;
  }

  function _amountToWithdrawAsset() internal pure virtual override returns (uint256) {
    return 2e8;
  }

  function _amountToWithdrawFarmToken() internal pure virtual override returns (uint256) {
    return 1e8;
  }
}

contract CompoundV3ConnectorInstance is BaseConnectorInstance, CompoundV3Connector {
  ICERC20 internal immutable _cToken;
  address internal immutable __asset;
  ICometRewards internal immutable _cometRewards;

  constructor(ICERC20 __cToken, address ___asset, ICometRewards __cometRewards) initializer {
    _cToken = __cToken;
    __asset = ___asset;
    _cometRewards = __cometRewards;
    _connector_init();
  }

  receive() external payable { }

  function cometRewards() public view override returns (ICometRewards) {
    return _cometRewards;
  }

  function cToken() public view override returns (ICERC20) {
    return _cToken;
  }

  function _asset() internal view override returns (address) {
    return address(__asset);
  }
}

contract CompoundV3ConnectorTestUSDC is CompoundV3ConnectorTest {
  ICERC20 internal cToken = ICERC20(0xF25212E676D1F7F89Cd72fFEe66158f541246445); // cUSDC
  IERC20 internal asset = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174); // USDC
  ICometRewards internal cometRewardsMock = ICometRewards(0x45939657d1CA34A8FA39A924B71D28Fe8431e581);
  // We need a holder for the cToken token
  address internal cTokenHolder = 0xB19ef8aE7528D74B747fbE16b46a394A02ccB14b; // cUSDC holder

  function _asset() internal view override returns (address) {
    return address(asset);
  }

  function _cToken() internal view override returns (ICERC20) {
    return cToken;
  }

  function _cometRewards() internal view override returns (ICometRewards) {
    return cometRewardsMock;
  }

  function _cTokenHolder() internal view override returns (address) {
    return cTokenHolder;
  }

  function _withdrawFarmTokenByAssetMaxDelta() internal pure override returns (uint256) {
    // Note: In the case of cDAI, 1 cDAI is equivalent to almost 15e9 DAI
    return 15e9;
  }
}
