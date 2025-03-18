// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import {
    NitroContractsEigenDA2Point1Point3UpgradeAction,
    ProxyAdmin,
    UpgradeSource
} from "../../../../contracts/parent-chain/contract-upgrades/NitroContractsEigenDA2Point1Point3UpgradeAction.sol";
import {IInboxBase} from "@arbitrum/nitro-contracts-1.2.1/src/bridge/IInboxBase.sol";
import {ISequencerInbox} from "@eigenda/nitro-contracts-2.1.3/src/bridge/ISequencerInbox.sol";
import {IERC20Bridge} from "@eigenda/nitro-contracts-2.1.3/src/bridge/IERC20Bridge.sol";
import {IRollupCore} from "@eigenda/nitro-contracts-2.1.3/src/rollup/IRollupCore.sol";
import {IUpgradeExecutor} from "@offchainlabs/upgrade-executor/src/IUpgradeExecutor.sol";

/**
 * @title ExecuteNitroContracts1Point2Point3UpgradeScript
 * @notice This script executes nitro contracts 2.1.3 upgrade or migration through UpgradeExecutor
 */
contract ExecuteNitroContractsEigenDA2Point1Point3UpgradeScript is Script {
    struct EnvVars {
        bool isCallerEigenDAV2_1_0;
        bytes32 targetWasmModuleRoot;
        uint256 maxDataSize;
        address inbox;
        address upgradeAction;
        address proxyAdmin;
        address parentUpgradeExecutor;
    }

    function loadEnv() internal view returns (EnvVars memory) {
        return EnvVars({
            isCallerEigenDAV2_1_0: vm.envBool("IS_EIGENDA_V2_1_0_CALLER"),
            targetWasmModuleRoot: vm.envBytes32("TARGET_WASM_MODULE_ROOT"),
            maxDataSize: vm.envUint("MAX_DATA_SIZE"),
            inbox: vm.envAddress("INBOX_ADDRESS"),
            upgradeAction: vm.envAddress("UPGRADE_ACTION_ADDRESS"),
            proxyAdmin: vm.envAddress("PROXY_ADMIN_ADDRESS"),
            parentUpgradeExecutor: vm.envAddress("PARENT_UPGRADE_EXECUTOR_ADDRESS")
        });
    }

    function run() public {
        EnvVars memory env = loadEnv();

        bool eigenDACaller = env.isCallerEigenDAV2_1_0;

        if (eigenDACaller) {
            console.log("Executing nitro-contracts v2.1.3 x eigenda upgrade from v2.1.0 eigenda chain");
        } else {
            console.log("Executing nitro-contracts v2.1.3 x eigenda upgrade from v2.1.3 arbitrum chain");
        }

        UpgradeSource src = eigenDACaller ? UpgradeSource.EigenDAV2Point1Zero : UpgradeSource.ArbitrumV2Point1Point3;

        IInboxBase inbox = IInboxBase(env.inbox);
        IRollupCore rollup = IRollupCore(address(inbox.bridge().rollup()));

        NitroContractsEigenDA2Point1Point3UpgradeAction upgradeAction =
            NitroContractsEigenDA2Point1Point3UpgradeAction(env.upgradeAction);
        // validate MAX_DATA_SIZE
        require(
            ISequencerInbox(upgradeAction.newEthInboxImpl()).maxDataSize() == env.maxDataSize
                || ISequencerInbox(upgradeAction.newERC20InboxImpl()).maxDataSize() == env.maxDataSize
                || ISequencerInbox(upgradeAction.newEthSequencerInboxImpl()).maxDataSize() == env.maxDataSize
                || ISequencerInbox(upgradeAction.newERC20SequencerInboxImpl()).maxDataSize() == env.maxDataSize,
            "MAX_DATA_SIZE mismatch with action"
        );
        require(inbox.maxDataSize() == env.maxDataSize, "MAX_DATA_SIZE mismatch with current deployment");

        // check prerequisites
        console.logBytes32(rollup.wasmModuleRoot());
        console.logBytes32(upgradeAction.newWasmModuleRoot());

        // prepare upgrade calldata
        // IRollupCore rollup, address inbox, ProxyAdmin proxyAdmin, UpgradeSource caller
        ProxyAdmin proxyAdmin = ProxyAdmin(env.proxyAdmin);
        bytes memory upgradeCalldata = abi.encodeCall(
            NitroContractsEigenDA2Point1Point3UpgradeAction.perform, (address(rollup), address(inbox), proxyAdmin, src)
        );

        // execute the upgrade
        // action checks prerequisites, and script will fail if the action reverts
        IUpgradeExecutor executor = IUpgradeExecutor(env.parentUpgradeExecutor);
        vm.startBroadcast();
        executor.execute(address(upgradeAction), upgradeCalldata);

        // sanity check, full checks are done on-chain by the upgrade action
        require(rollup.wasmModuleRoot() == upgradeAction.newWasmModuleRoot(), "Wasm module root not set");
        require(rollup.wasmModuleRoot() == env.targetWasmModuleRoot, "Unexpected wasm module root set");
        vm.stopBroadcast();
    }
}
