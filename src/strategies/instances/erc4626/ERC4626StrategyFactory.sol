// SPDX-License-Identifier: MIT
pragma solidity >=0.8.22;

import { IEarnVault, IEarnStrategyRegistry } from "@balmy/earn-core/interfaces/IEarnStrategy.sol";
import { StrategyId, StrategyIdConstants } from "@balmy/earn-core/types/StrategyId.sol";
import { IEarnBalmyStrategy } from "../../../interfaces/IEarnBalmyStrategy.sol";
import { IGlobalEarnRegistry } from "../../../interfaces/IGlobalEarnRegistry.sol";
import { BaseStrategyFactory } from "../base/BaseStrategyFactory.sol";
import { ERC4626Strategy, IGlobalEarnRegistry, IERC4626 } from "./ERC4626Strategy.sol";

contract ERC4626StrategyFactory is BaseStrategyFactory {
  constructor(ERC4626Strategy implementation_) BaseStrategyFactory(implementation_) { }

  function cloneStrategy(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    public
    returns (ERC4626Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, erc4626Vault);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = ERC4626Strategy(payable(address(clone_)));
    clone.init(tosData, guardianData, feesData, description);
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
  }

  function cloneStrategyAndRegister(
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (ERC4626Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, erc4626Vault);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = ERC4626Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(owner, tosData, guardianData, feesData, description);
    emit StrategyCloned(clone, strategyId);
  }

  function clone2Strategy(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (ERC4626Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, erc4626Vault);
    IEarnBalmyStrategy clone_ = _clone2(immutableData);
    clone = ERC4626Strategy(payable(address(clone_)));
    clone.init(tosData, guardianData, feesData, description);
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
  }

  function clone2StrategyAndRegister(
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (ERC4626Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, erc4626Vault);
    IEarnBalmyStrategy clone_ = _clone(immutableData);
    clone = ERC4626Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(owner, tosData, guardianData, feesData, description);
    emit StrategyCloned(clone, strategyId);
  }

  function clone3Strategy(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes32 salt,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (ERC4626Strategy clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, erc4626Vault);
    IEarnBalmyStrategy clone_ = _clone3(immutableData, salt);
    clone = ERC4626Strategy(payable(address(clone_)));
    clone.init(tosData, guardianData, feesData, description);
    emit StrategyCloned(clone, StrategyIdConstants.NO_STRATEGY);
  }

  function clone3StrategyAndRegister(
    address owner,
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault,
    bytes32 salt,
    bytes calldata tosData,
    bytes calldata guardianData,
    bytes calldata feesData,
    string calldata description
  )
    external
    returns (ERC4626Strategy clone, StrategyId strategyId)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, erc4626Vault);
    IEarnBalmyStrategy clone_ = _clone3(immutableData, salt);
    clone = ERC4626Strategy(payable(address(clone_)));
    strategyId = clone.initAndRegister(owner, tosData, guardianData, feesData, description);
    emit StrategyCloned(clone, strategyId);
  }

  function addressOfClone2(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault
  )
    external
    view
    returns (address clone)
  {
    bytes memory immutableData = _calculateImmutableData(earnVault, globalRegistry, erc4626Vault);
    return _addressOfClone2(immutableData);
  }

  function _calculateImmutableData(
    IEarnVault earnVault,
    IGlobalEarnRegistry globalRegistry,
    IERC4626 erc4626Vault
  )
    internal
    view
    returns (bytes memory)
  {
    address asset = erc4626Vault.asset();
    return abi.encodePacked(earnVault, globalRegistry, erc4626Vault, asset);
  }
}
