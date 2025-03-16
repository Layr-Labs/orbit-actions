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
contract ExecuteNitroContracts2Point1Point3UpgradeScript is Script {
    function run() public {
        bool eigenDACaller = vm.envBool("IS_EIGENDA_V2_1_0_CALLER");

        if (eigenDACaller) {
            console.log("Executing nitro-contracts v2.1.3 x eigenda upgrade from v2.1.0 eigenda chain");
        } else {
            console.log("Executing nitro-contracts v2.1.3 x eigenda upgrade from v2.1.3 arbitrum chain");
        }

        UpgradeSource src = eigenDACaller ? UpgradeSource.EigenDAV2Point1Zero : UpgradeSource.ArbitrumV2Point1Point3;

        IInboxBase inbox = IInboxBase(vm.envAddress("INBOX_ADDRESS"));
        IRollupCore rollup = IRollupCore(address(inbox.bridge().rollup()));

        // used to check if upgrade was successful
        bytes32 wasmModuleRoot = vm.envBytes32("TARGET_WASM_MODULE_ROOT");

        NitroContractsEigenDA2Point1Point3UpgradeAction upgradeAction =
            NitroContractsEigenDA2Point1Point3UpgradeAction(vm.envAddress("UPGRADE_ACTION_ADDRESS"));
        // validate MAX_DATA_SIZE
        uint256 maxDataSize = vm.envUint("MAX_DATA_SIZE");
        require(
            ISequencerInbox(upgradeAction.newEthInboxImpl()).maxDataSize() == maxDataSize
                || ISequencerInbox(upgradeAction.newERC20InboxImpl()).maxDataSize() == maxDataSize
                || ISequencerInbox(upgradeAction.newEthSequencerInboxImpl()).maxDataSize() == maxDataSize
                || ISequencerInbox(upgradeAction.newERC20SequencerInboxImpl()).maxDataSize() == maxDataSize,
            "MAX_DATA_SIZE mismatch with action"
        );
        require(inbox.maxDataSize() == maxDataSize, "MAX_DATA_SIZE mismatch with current deployment");

        // check prerequisites
        require(rollup.wasmModuleRoot() == upgradeAction.newWasmModuleRoot(), "Incorrect starting wasm module root");

        // prepare upgrade calldata
        // IRollupCore rollup, address inbox, ProxyAdmin proxyAdmin, UpgradeSource caller
        ProxyAdmin proxyAdmin = ProxyAdmin(vm.envAddress("PROXY_ADMIN_ADDRESS"));
        bytes memory upgradeCalldata = abi.encodeCall(
            NitroContractsEigenDA2Point1Point3UpgradeAction.perform, (address(rollup), address(inbox), proxyAdmin, src)
        );

        // execute the upgrade
        // action checks prerequisites, and script will fail if the action reverts
        IUpgradeExecutor executor = IUpgradeExecutor(vm.envAddress("PARENT_UPGRADE_EXECUTOR_ADDRESS"));
        vm.startBroadcast();
        executor.execute(address(upgradeAction), upgradeCalldata);

        // sanity check, full checks are done on-chain by the upgrade action
        require(rollup.wasmModuleRoot() == upgradeAction.newWasmModuleRoot(), "Wasm module root not set");
        require(rollup.wasmModuleRoot() == wasmModuleRoot, "Unexpected wasm module root set");
        vm.stopBroadcast();
    }
}
