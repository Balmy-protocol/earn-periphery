// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import {
  BaseConnector,
  IEarnStrategy,
  SpecialWithdrawalCode,
  IDelayedWithdrawalAdapter,
  StrategyId
} from "../base/BaseConnector.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SpecialWithdrawal } from "@balmy/earn-core/types/SpecialWithdrawals.sol";

interface ILidoSTETH is IERC20 {
  function submit(address _referral) external payable returns (uint256);
  function getTotalPooledEther() external view returns (uint256);
  function getTotalShares() external view returns (uint256);
}

abstract contract LidoSTETHConnector is BaseConnector, Initializable {
  using SafeERC20 for IERC20;
  using Math for uint256;

  address private constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  // slither-disable-start naming-convention
  // solhint-disable-next-line const-name-snakecase
  ILidoSTETH private constant _stETH = ILidoSTETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
  // slither-disable-end naming-convention

  function _delayedWithdrawalAdapter() internal view virtual returns (IDelayedWithdrawalAdapter);

  // slither-disable-next-line naming-convention,dead-code
  function _connector_asset() internal pure override returns (address) {
    return _ETH;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_allTokens() internal pure override returns (address[] memory tokens) {
    tokens = new address[](1);
    tokens[0] = _connector_asset();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedWithdrawals()
    internal
    view
    virtual
    override
    returns (IEarnStrategy.WithdrawalType[] memory withdrawalTypes)
  {
    withdrawalTypes = new IEarnStrategy.WithdrawalType[](1);
    withdrawalTypes[0] = IEarnStrategy.WithdrawalType.DELAYED;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isDepositTokenSupported(address depositToken) internal view virtual override returns (bool) {
    return depositToken == _connector_asset() || depositToken == address(_stETH);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_deposit(
    address depositToken,
    uint256 depositAmount
  )
    internal
    override
    returns (uint256 assetsDeposited)
  {
    if (depositToken == _connector_asset()) {
      uint256 balanceBefore = IERC20(_stETH).balanceOf(address(this));
      // slither-disable-next-line unused-return
      _stETH.submit{ value: depositAmount }(address(0));
      uint256 balanceAfter = IERC20(_stETH).balanceOf(address(this));
      return balanceAfter - balanceBefore;
    } else if (depositToken == address(_stETH)) {
      IERC20(depositToken).safeTransferFrom(msg.sender, address(this), depositAmount);
      return depositAmount;
    } else {
      revert InvalidDepositToken(depositToken);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedDepositTokens() internal pure override returns (address[] memory supported) {
    supported = new address[](2);
    supported[0] = _connector_asset();
    supported[1] = address(_stETH);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxDeposit(address depositToken) internal view override returns (uint256) {
    if (!_connector_isDepositTokenSupported(depositToken)) {
      revert InvalidDepositToken(depositToken);
    }
    return type(uint256).max;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_isSpecialWithdrawalSupported(SpecialWithdrawalCode withdrawalCode)
    internal
    pure
    override
    returns (bool)
  {
    return withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT
      || withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_supportedSpecialWithdrawals()
    internal
    pure
    override
    returns (SpecialWithdrawalCode[] memory codes)
  {
    codes = new SpecialWithdrawalCode[](2);
    codes[0] = SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT;
    codes[1] = SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT;
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_maxWithdraw()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory withdrawable)
  {
    (tokens, withdrawable) = _connector_totalBalances();
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_totalBalances()
    internal
    view
    override
    returns (address[] memory tokens, uint256[] memory balances)
  {
    tokens = _connector_allTokens();
    balances = new uint256[](tokens.length);
    balances[0] = IERC20(address(_stETH)).balanceOf(address(this));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_delayedWithdrawalAdapter(address token)
    internal
    view
    virtual
    override
    returns (IDelayedWithdrawalAdapter)
  {
    if (token == _ETH) {
      return _delayedWithdrawalAdapter();
    }
    return IDelayedWithdrawalAdapter(address(0));
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_withdraw(
    uint256 positionId,
    address[] memory,
    uint256[] memory toWithdraw,
    address
  )
    internal
    override
  {
    IERC20(address(_stETH)).safeTransfer(address(_connector_delayedWithdrawalAdapter(_ETH)), toWithdraw[0]);
    _connector_delayedWithdrawalAdapter(_ETH).initiateDelayedWithdrawal(positionId, _ETH, toWithdraw[0]);
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_specialWithdraw(
    uint256,
    SpecialWithdrawalCode withdrawalCode,
    uint256[] calldata toWithdraw,
    bytes calldata,
    address recipient
  )
    internal
    override
    returns (
      uint256[] memory balanceChanges,
      address[] memory actualWithdrawnTokens,
      uint256[] memory actualWithdrawnAmounts,
      bytes memory result
    )
  {
    if (
      withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_AMOUNT
        || withdrawalCode == SpecialWithdrawal.WITHDRAW_ASSET_FARM_TOKEN_BY_ASSET_AMOUNT
    ) {
      balanceChanges = new uint256[](_connector_allTokens().length);
      actualWithdrawnTokens = new address[](1);
      actualWithdrawnAmounts = new uint256[](1);
      result = "";
      uint256 assets = toWithdraw[0];
      IERC20(address(_stETH)).safeTransfer(recipient, assets);
      balanceChanges[0] = assets;
      actualWithdrawnTokens[0] = address(_stETH);
      actualWithdrawnAmounts[0] = assets;
    } else {
      revert InvalidSpecialWithdrawalCode(withdrawalCode);
    }
  }

  // slither-disable-next-line naming-convention,dead-code
  function _connector_migrateToNewStrategy(
    IEarnStrategy newStrategy,
    bytes calldata
  )
    internal
    override
    returns (bytes memory)
  {
    uint256 balance = IERC20(address(_stETH)).balanceOf(address(this));
    IERC20(address(_stETH)).safeTransfer(address(newStrategy), balance);
    return abi.encode(balance);
  }

  // solhint-disable no-empty-blocks
  // slither-disable-next-line naming-convention,dead-code
  function _connector_strategyRegistered(
    StrategyId strategyId,
    IEarnStrategy oldStrategy,
    bytes calldata migrationData
  )
    internal
    override
  { }
}
