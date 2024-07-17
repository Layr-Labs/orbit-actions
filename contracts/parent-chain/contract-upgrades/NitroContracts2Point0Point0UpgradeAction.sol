// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "@arbitrum/nitro-contracts-2.0.0/src/osp/IOneStepProofEntry.sol";
import "@arbitrum/nitro-contracts-2.0.0/src/rollup/IRollupAdmin.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

interface IChallengeManagerUpgradeInit {
    function postUpgradeInit(IOneStepProofEntry osp_, bytes32 condRoot, IOneStepProofEntry condOsp) external;
    function osp() external returns (address);
}

interface IRollupUpgrade {
    function upgradeTo(address newImplementation) external;
    function upgradeSecondaryTo(address newImplementation) external;
}

/**
 * @title DeployNitroContracts2Point0Point0UpgradeActionScript
 * @notice  Set wasm module root and upgrade challenge manager for stylus ArbOS upgrade.
 *          Also upgrade Rollup logic contracts to include fast confirmations feature.
 */
contract NitroContracts2Point0Point0UpgradeAction {
    bytes32 public immutable newWasmModuleRoot;
    address public immutable newChallengeManagerImpl;
    IOneStepProofEntry public immutable osp;
    bytes32 public immutable condRoot;
    IOneStepProofEntry public immutable condOsp;

    address public immutable newRollupAdminLogic;
    address public immutable newRollupUserLogic;

    bytes32 internal constant _IMPLEMENTATION_SECONDARY_SLOT =
        0x2b1dbce74324248c222f0ec2d5ed7bd323cfc425b336f0253c5ccfda7265546d;
    bytes32 private constant _IMPLEMENTATION_PRIMARY_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(
        bytes32 _newWasmModuleRoot,
        address _newChallengeManagerImpl,
        IOneStepProofEntry _osp,
        bytes32 _condRoot,
        IOneStepProofEntry _condOsp,
        address _newRollupAdminLogic,
        address _newRollupUserLogic
    ) {
        require(
            _newWasmModuleRoot != bytes32(0), "NitroContracts2Point0Point0UpgradeAction: _newWasmModuleRoot is empty"
        );
        require(
            Address.isContract(_newChallengeManagerImpl),
            "NitroContracts2Point0Point0UpgradeAction: _newChallengeManagerImpl is not a contract"
        );
        require(Address.isContract(address(_osp)), "NitroContracts2Point0Point0UpgradeAction: _osp is not a contract");
        require(
            Address.isContract(address(_condOsp)),
            "NitroContracts2Point0Point0UpgradeAction: _condOsp is not a contract"
        );
        require(
            Address.isContract(_newRollupAdminLogic),
            "NitroContracts2Point0Point0UpgradeAction: _newRollupAdminLogic is not a contract"
        );
        require(
            Address.isContract(_newRollupUserLogic),
            "NitroContracts2Point0Point0UpgradeAction: _newRollupUserLogic is not a contract"
        );

        newWasmModuleRoot = _newWasmModuleRoot;
        newChallengeManagerImpl = _newChallengeManagerImpl;
        osp = _osp;
        condRoot = _condRoot;
        condOsp = _condOsp;
        newRollupAdminLogic = _newRollupAdminLogic;
        newRollupUserLogic = _newRollupUserLogic;
    }

    function perform(IRollupCore rollup, ProxyAdmin proxyAdmin) external {
        _upgradeChallengerManager(rollup, proxyAdmin);
        _upgradeRollup(address(rollup));
    }

    function _upgradeChallengerManager(IRollupCore rollup, ProxyAdmin proxyAdmin) internal {
        // set the new challenge manager impl
        TransparentUpgradeableProxy challengeManager =
            TransparentUpgradeableProxy(payable(address(rollup.challengeManager())));
        proxyAdmin.upgradeAndCall(
            challengeManager,
            newChallengeManagerImpl,
            abi.encodeCall(IChallengeManagerUpgradeInit.postUpgradeInit, (osp, condRoot, condOsp))
        );

        // verify
        require(
            proxyAdmin.getProxyImplementation(challengeManager) == newChallengeManagerImpl,
            "NitroContracts2Point0Point0UpgradeAction: new challenge manager implementation set"
        );
        require(
            IChallengeManagerUpgradeInit(address(challengeManager)).osp() == address(osp),
            "NitroContracts2Point0Point0UpgradeAction: new OSP not set"
        );

        // set new wasm module root
        IRollupAdmin(address(rollup)).setWasmModuleRoot(newWasmModuleRoot);

        // verify:
        require(
            rollup.wasmModuleRoot() == newWasmModuleRoot,
            "NitroContracts2Point0Point0UpgradeAction: wasm module root not set"
        );
    }

    function _upgradeRollup(address rollupProxy) internal {
        IRollupUpgrade rollup = IRollupUpgrade(rollupProxy);
        address _newAdminLogic = newRollupAdminLogic;
        address _newUserLogic = newRollupUserLogic;

        // set new logic contracts
        rollup.upgradeTo(_newAdminLogic);
        rollup.upgradeSecondaryTo(_newUserLogic);

        // verify
        address currentAdminLogic;
        assembly {
            currentAdminLogic := sload(_IMPLEMENTATION_PRIMARY_SLOT)
        }
        require(
            currentAdminLogic == _newAdminLogic, "NitroContracts2Point0Point0UpgradeAction: new admin logic not set"
        );

        address currentUserLogic;
        assembly {
            currentUserLogic := sload(_IMPLEMENTATION_SECONDARY_SLOT)
        }
        require(currentUserLogic == _newUserLogic, "NitroContracts2Point0Point0UpgradeAction: new user logic not set");
    }
}
