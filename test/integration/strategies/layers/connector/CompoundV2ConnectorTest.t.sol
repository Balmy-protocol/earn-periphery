// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import {
  CompoundV2Connector, IERC20, ICERC20, IComptroller
} from "src/strategies/layers/connector/CompoundV2Connector.sol";
import { BaseConnectorInstance, BaseConnector } from "./base/BaseConnectorInstance.sol";
import { BaseConnectorImmediateWithdrawalTest } from "./base/BaseConnectorImmediateWithdrawalTest.t.sol";
import { BaseConnectorFarmTokenTest } from "./base/BaseConnectorFarmTokenTest.t.sol";
import { Token } from "@balmy/earn-core/libraries/Token.sol";

abstract contract CompoundV2ConnectorTest is BaseConnectorImmediateWithdrawalTest, BaseConnectorFarmTokenTest {
  // solhint-disable-next-line no-empty-blocks
  function _setUp() internal override { }

  function _asset() internal view virtual returns (address);
  function _comp() internal view virtual returns (IERC20);
  function _cToken() internal view virtual returns (ICERC20);
  function _cTokenHolder() internal view virtual returns (address);

  function _configureFork() internal override {
    uint256 mainnetFork = vm.createFork(vm.rpcUrl("mainnet"));
    vm.selectFork(mainnetFork);

    vm.rollFork(21_079_000);
    vm.makePersistent(address(_farmToken())); // We need to make the farm token persistent for the next roll fork
  }

  function _buildNewConnector() internal override returns (BaseConnectorInstance) {
    return new CompoundV2ConnectorInstance(_cToken(), _asset(), new CompoundV2ComptrollerMock(), _comp());
  }

  function _farmToken() internal view virtual override returns (address) {
    return address(_cToken());
  }

  function testFork_rewardEmissionsPerSecondPerAsset() public {
    CompoundV2ConnectorInstance compoundV2Connector =
      new CompoundV2ConnectorInstance(_cToken(), _asset(), new CompoundV2ComptrollerMock(), _comp());

    (uint256[] memory emissions, uint256[] memory multipliers) = compoundV2Connector.rewardEmissionsPerSecondPerAsset();

    assertEq(emissions.length, 1);
    assertEq(emissions[0], 1e10 * 1e30 / IERC20(address(_cToken())).totalSupply());
    assertEq(multipliers.length, 1);
    assertEq(multipliers[0], 1e30);
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

  function _generateYield(BaseConnector _connector) internal virtual override {
    CompoundV2ComptrollerMock comptrollerMock =
      CompoundV2ComptrollerMock(payable(address(CompoundV2Connector(payable(address(_connector))).comptroller())));
    _setBalance(address(_comp()), address(comptrollerMock), 1e13);
    comptrollerMock._generateYield(1e3);
  }

  function _connectorBalanceOfFarmToken() internal pure override returns (uint256) {
    return 10e12;
  }

  function _amountToWithdraw() internal pure override returns (uint256) {
    return 2e5;
  }
}

contract CompoundV2ConnectorInstance is BaseConnectorInstance, CompoundV2Connector {
  ICERC20 internal immutable _cToken;
  address internal immutable __asset;
  IComptroller internal immutable _cCompoundV2Comptroller;
  IERC20 internal immutable _comp;

  constructor(ICERC20 __cToken, address ___asset, IComptroller __cCompoundV2Comptroller, IERC20 __comp) initializer {
    _cToken = __cToken;
    __asset = ___asset;
    _cCompoundV2Comptroller = __cCompoundV2Comptroller;
    _comp = __comp;
    _connector_init();
  }

  function comptroller() public view override returns (IComptroller) {
    return _cCompoundV2Comptroller;
  }

  function cToken() public view override returns (ICERC20) {
    return _cToken;
  }

  function _asset() internal view override returns (address) {
    return address(__asset);
  }

  function rewardEmissionsPerSecondPerAsset() external view returns (uint256[] memory, uint256[] memory) {
    return _connector_rewardEmissionsPerSecondPerAsset();
  }

  function comp() public view virtual override returns (IERC20) {
    return _comp;
  }
}

contract CompoundV2ComptrollerMock is IComptroller {
  IERC20 internal _comp = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888); // COMP

  uint256 internal yieldGenerated = 0;

  function compSpeeds(address) external pure returns (uint256) {
    return 1e10;
  }

  function _generateYield(uint256 blocks) external {
    yieldGenerated += blocks * 1e10;
  }

  function claimComp(address[] memory holders, ICERC20[] memory, bool, bool) external override {
    _comp.transfer(holders[0], yieldGenerated);
    // solhint-disable-next-line reentrancy
    yieldGenerated = 0;
  }

  function compAccrued(address) external view override returns (uint256) {
    return yieldGenerated;
  }

  function mintGuardianPaused(ICERC20) external pure override returns (bool) {
    return false;
  }
}

contract CompoundV2ConnectorTestERC20 is CompoundV2ConnectorTest {
  ICERC20 internal cToken = ICERC20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643); // cDAI
  IERC20 internal asset = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
  IERC20 internal comp = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888); // COMP
  // We need a holder for the cToken token
  address internal cTokenHolder = 0xB0b0F6F13A5158eB67724282F586a552E75b5728; // cDAI holder

  function _asset() internal view override returns (address) {
    return address(asset);
  }

  function _comp() internal view override returns (IERC20) {
    return comp;
  }

  function _cToken() internal view override returns (ICERC20) {
    return cToken;
  }

  function _cTokenHolder() internal view override returns (address) {
    return cTokenHolder;
  }
}

contract CompoundV2ConnectorTestNative is CompoundV2ConnectorTest {
  ICERC20 internal cToken = ICERC20(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5); // cETH
  address internal asset = Token.NATIVE_TOKEN; // ETH
  IERC20 internal comp = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888); // COMP

  // We need a holder for the cToken token
  address internal cTokenHolder = 0x08CFd293D687B6CEe139219a607ACBBC10A6eb25; // cETH holder

  function _asset() internal view override returns (address) {
    return asset;
  }

  function _comp() internal view override returns (IERC20) {
    return comp;
  }

  function _cToken() internal view override returns (ICERC20) {
    return cToken;
  }

  function _cTokenHolder() internal view override returns (address) {
    return cTokenHolder;
  }
}
