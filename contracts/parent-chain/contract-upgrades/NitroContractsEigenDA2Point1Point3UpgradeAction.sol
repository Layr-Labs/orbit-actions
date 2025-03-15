// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "@eigenda/nitro-contracts-2.1.3/src/osp/IOneStepProofEntry.sol";
import "@eigenda/nitro-contracts-2.1.3/src/rollup/IRollupAdmin.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// UpgradeSource denotes the caller context of the upgrade
// and is used to conditionally construct a conditonal one step prover
// used for temporary backwards compatibility
enum UpgradeSource {
    EigenDAV2Point1Zero,
    ArbitrumV2Point1Point3
}

interface IEigenV2Point1SeqInbox {
    function eigenDARollupManager() external view returns (address);
}

interface IInbox {
    function bridge() external view returns (address);
    function sequencerInbox() external view returns (address);
    function allowListEnabled() external view returns (bool);
}

interface IERC20Bridge {
    function nativeToken() external view returns (address);
}

interface IERC20Bridge_v2 {
    function nativeTokenDecimals() external view returns (uint8);
}

interface IChallengeManagerUpgradeInit {
    function postUpgradeInit(IOneStepProofEntry osp_, bytes32 condRoot, IOneStepProofEntry condOsp) external;
    function osp() external returns (address);
}

/**
 * @title   NitroContractsEigenDA2Point1Point3UpgradeAction
 * @notice  Upgrades to using EigenDA forked contracts (SequencerInbox, ChallengeManager)
 *          & Delayed Inbox if upgrade is being invoked by EigenDA chain
 *          Will revert if the bridge is an ERC20Bridge below v2.x.x
 */
contract NitroContractsEigenDA2Point1Point3UpgradeAction {
    /**
     * @dev condOsp is used to ensure backwards compatibility for temporarily resolving
     *      one step proofs for assertion nodes using pre-upgrade version. It's expected
     *      that this will only be callable until last pre-upgrade claim node has
     *      been confirmed on the assertion chain.
     *
     *      caller context can be either:
     *        - eigenda x nitro-contracts v2.1.0
     *        - nitro-contracts v2.1.3
     *
     *      since the nitro-contracts v2.1.0 --> v2.1.3 upgrade doesn't change the OSP
     *      artifact then using the nitro-contracts x eigenda v2.1.0 OSP for both caller
     *      contexts is sufficent. The conditional wasm module root doesn't have to be caller
     *      context specific since consensus root V32 has not been updated since v2.1.0 upgrade.
     *
     * @dev this approach assumes that only one condOsp will exist for backwards compatible
     *      proving. THIS SHOULD NEVER be invoked by a chain with >1 module roots in an unconfirmed
     *      assertion chain since the first module root woul be unresolvable given the OSP artifact
     *      wouldn't exist post upgrade. E.g. doing a migration from other DA fork -> AnyTrust -> EigenDA
     */

    // based on caller context
    bytes32 public immutable condRoot;

    // core arbitrum v2.1.3 upgrade action contracts
    address public immutable newEthInboxImpl;
    address public immutable newERC20InboxImpl;

    // intersection artifact - also necessary for upgrading to eigenda forked contracts!
    address public immutable newEthSequencerInboxImpl;
    address public immutable newERC20SequencerInboxImpl;

    // eigenda forked contracts
    address public immutable newChallengeManagerImpl;
    bytes32 public immutable newWasmModuleRoot;
    IOneStepProofEntry public immutable newOSP;

    constructor(
        address _newEthInboxImpl,
        address _newERC20InboxImpl,
        address _newEthSequencerInboxImpl,
        address _newERC20SequencerInboxImpl,
        address _newChallengeManagerImpl,
        IOneStepProofEntry _osp,
        bytes32 _newWasmModuleRoot,
        bytes32 _condRoot
    ) {
        require(
            Address.isContract(_newEthInboxImpl),
            "NitroContractsEigenDA2Point1Point3UpgradeAction: _newEthInboxImpl is not a contract"
        );
        require(
            Address.isContract(_newERC20InboxImpl),
            "NitroContractsEigenDA2Point1Point3UpgradeAction: _newERC20InboxImpl is not a contract"
        );
        require(
            Address.isContract(_newEthSequencerInboxImpl),
            "NitroContractsEigenDA2Point1Point3UpgradeAction: _newEthSequencerInboxImpl is not a contract"
        );
        require(
            Address.isContract(_newERC20SequencerInboxImpl),
            "NitroContractsEigenDA2Point1Point3UpgradeAction: _newERC20SequencerInboxImpl is not a contract"
        );

        require(
            Address.isContract(_newChallengeManagerImpl),
            "NitroContractsEigenDA2Point1Point3UpgradeAction: _newChallengeManagerImpl is not a contract"
        );

        // set v2.1.3 upgrade action contracts
        newEthInboxImpl = _newEthInboxImpl;
        newERC20InboxImpl = _newERC20InboxImpl;
        newEthSequencerInboxImpl = _newEthSequencerInboxImpl;
        newERC20SequencerInboxImpl = _newERC20SequencerInboxImpl;

        // set eigenda x v2.1.3 contracts
        newOSP = _osp;
        newWasmModuleRoot = _newWasmModuleRoot;
        condRoot = _condRoot;
        newChallengeManagerImpl = _newChallengeManagerImpl;
    }

    /**
     * @dev if upgrading from eigenda rollup then verify that rollup manager accessor
     *      lives on sequencer inbox. verify inverse for base arbitrum chain case.
     * @param caller source context
     * @param sequencerInbox address of sequencer inbox contract
     */
    function _verifySourceContext(UpgradeSource caller, address sequencerInbox, IRollupCore rollup) internal view {
        if (caller == UpgradeSource.EigenDAV2Point1Zero) {
            try IEigenV2Point1SeqInbox(sequencerInbox).eigenDARollupManager() returns (address) {}
            catch {
                revert("NitroContractsEigenDA2Point1Point3UpgradeAction: INCORRECT_CALLER_SOURCE_EIGENDA");
            }

            require(rollup.wasmModuleRoot() == newWasmModuleRoot, "EXPECTED_WASM_ROOT_EIGENDA_CONSENSUS_V32");
        } else {
            try IEigenV2Point1SeqInbox(sequencerInbox).eigenDARollupManager() returns (address) {}
            catch {
                require(rollup.wasmModuleRoot() == condRoot, "EXPECTED_WASM_ROOT_ARBITRUM_CONSENSUS_V32");
                return;
            }
            revert("NitroContractsEigenDA2Point1Point3UpgradeAction: INCORRECT_CALLER_SOURCE");
        }
    }

    /**
     * @dev only intersection between eigenda x contracts change set
     * & base v2.1.3 upgrade action is the Sequencer Inbox contract.
     * Therefore it is deployed using the 2.1.3 action logic
     * @param rollup admin contract used for updating module root
     * @param proxyAdmin admin contract used for updating implementation references
     * @param caller the upgrading chain source type
     */
    function perform(address rollup, address inbox, ProxyAdmin proxyAdmin, UpgradeSource caller) external {
        address sequencerInbox = IInbox(inbox).sequencerInbox();

        IRollupCore rollupCore = IRollupCore(rollup);
        _verifySourceContext(caller, sequencerInbox, rollupCore);

        address bridge = IInbox(inbox).bridge();
        bool isERC20 = false;

        // // if the bridge is an ERC20Bridge below v2.x.x, revert
        try IERC20Bridge(bridge).nativeToken() returns (address) {
            isERC20 = true;
            // it is an ERC20Bridge, check if it is on v2.x.x
            try IERC20Bridge_v2(address(bridge)).nativeTokenDecimals() returns (uint8) {}
            catch {
                // it is not on v2.x.x, revert
                revert("NitroContractsEigenDA2Point1Point3UpgradeAction: bridge is an ERC20Bridge below v2.x.x");
            }
        } catch {}

        // upgrade eigenda specific contracts
        // ie sequencer inbox, one step prover
        _performEigenDA2Point1Point3Upgrade(rollupCore, proxyAdmin, sequencerInbox, caller, isERC20);

        // determine whether to also upgrade base v2.1.3 contracts.
        // this is unnecessary if being called by upgrade executor for vanilla
        // orbit chain since this would be a wasteful operation.
        if (caller == UpgradeSource.EigenDAV2Point1Zero) {
            _performBase2Point1Point3Upgrade(inbox, proxyAdmin, isERC20);
        }
    }

    /**
     * @dev Upgrades to using eigenda forked contracts
     * @param rollup admin contract used for updating module root
     * @param proxyAdmin admin contract used for upgrading sequencer inbox & challenge manager
     * @param sequencerInbox sequencer inbox address
     * @param src caller context of upgrade
     * @param isERC20 denotes whether custom gas token or native ETH for rollup asset
     */
    function _performEigenDA2Point1Point3Upgrade(
        IRollupCore rollup,
        ProxyAdmin proxyAdmin,
        address sequencerInbox,
        UpgradeSource src,
        bool isERC20
    ) internal {
        // (1) upgrade the sequencer inbox
        proxyAdmin.upgrade({
            proxy: TransparentUpgradeableProxy(payable((sequencerInbox))),
            implementation: isERC20 ? newERC20SequencerInboxImpl : newEthSequencerInboxImpl
        });

        // (2) upgrade one step prover and set via new challenge manager field
        _upgradeChallengerManager(rollup, proxyAdmin, src);
    }

    function _performBase2Point1Point3Upgrade(address inbox, ProxyAdmin proxyAdmin, bool isERC20) internal {
        // older upgrade action used to use the "rollup" address as the argument
        // for 2.1.3 we cannot discover the inbox from the rollup, so instead we have to supply the inbox address
        // this can be dangerous because both `bridge()` and `sequencerInbox()` also exists in the rollup contract
        // the following check makes sure inbox is inbox as `allowListEnabled()` only exists in the inbox contract
        try IInbox(inbox).allowListEnabled() returns (bool) {}
        catch {
            revert("NitroContractsEigenDA2Point1Point3UpgradeAction: inbox is not an inbox");
        }

        // upgrade the delayed inbox
        proxyAdmin.upgrade({
            proxy: TransparentUpgradeableProxy(payable((inbox))),
            implementation: isERC20 ? newERC20InboxImpl : newEthInboxImpl
        });
    }

    function _upgradeChallengerManager(IRollupCore rollup, ProxyAdmin proxyAdmin, UpgradeSource src) internal {
        // set the new challenge manager impl
        TransparentUpgradeableProxy challengeManager =
            TransparentUpgradeableProxy(payable(address(rollup.challengeManager())));

        // set calldata based on source context
        // there's no need to set a conditional one step prover.
        // mapping the eigenda v2.1.3 one step prover to the arbitrum v2.1.3 cond wasm root is
        // sufficient since the eigenda v2.1.3 osp is a superset of the arbitrum v2.1.3 osp logic
        // with extensions only made for read preimage proving for an EigenDA preimage type.
        // by default the challenge

        bytes memory postUpgradeCalldata =
            abi.encodeCall(IChallengeManagerUpgradeInit.postUpgradeInit, (newOSP, condRoot, newOSP));

        // upgrade challenge manager & delegate call to new implementation method (if applicable)
        proxyAdmin.upgradeAndCall(challengeManager, newChallengeManagerImpl, postUpgradeCalldata);

        // verify implementation logic for challenge manager has been updated
        // & the latest one step prover matches the one provided to the contract
        require(
            proxyAdmin.getProxyImplementation(challengeManager) == newChallengeManagerImpl,
            "NitroContractsEigenDA2Point1Point3UpgradeAction: new challenge manager implementation set"
        );
        require(
            IChallengeManagerUpgradeInit(address(challengeManager)).osp() == address(newOSP),
            "NitroContractsEigenDA2Point1Point3UpgradeAction: new OSP not set"
        );

        // only set new wasm module root to nitro-contracts x eigenda
        //  v2.1.3 if upgrading from vanilla Arbitrum chain.
        if (src == UpgradeSource.ArbitrumV2Point1Point3) {
            IRollupAdmin(address(rollup)).setWasmModuleRoot(newWasmModuleRoot);

            // verify that module root was actually upgraded
            require(
                rollup.wasmModuleRoot() == newWasmModuleRoot,
                "NitroContractsEigenDA2Point1Point3UpgradeAction: wasm module root not set"
            );
        }
    }
}
