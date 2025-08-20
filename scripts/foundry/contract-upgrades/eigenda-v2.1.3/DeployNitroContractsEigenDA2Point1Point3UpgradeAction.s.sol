// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {DeploymentHelpersScript} from "../../helper/DeploymentHelpers.s.sol";
import {
    NitroContractsEigenDA2Point1Point3UpgradeAction,
    IOneStepProofEntry
} from "../../../../contracts/parent-chain/contract-upgrades/NitroContractsEigenDA2Point1Point3UpgradeAction.sol";
import {MockArbSys} from "../../helper/MockArbSys.sol";

import "forge-std/Script.sol";

/**
 * @title DeployNitroContractsEigenDA2Point1Point3UpgradeActionScript
 * @notice This script deploys the bridge, challenger manager, and NitroContractsEigenDA2Point1Point3UpgradeAction contract.
 */
contract DeployNitroContractsEigenDA2Point1Point3UpgradeActionScript is DeploymentHelpersScript {
    // ArbOS x EigenDA v32.3 https://github.com/Layr-Labs/nitro/releases/tag/consensus-eigenda-v32.3
    bytes32 public constant WASM_MODULE_ROOT = 0x39a7b951167ada11dc7c81f1707fb06e6710ca8b915b2f49e03c130bf7cd53b1;

    function deployOSPEigenDAV2Point1Point3Impl() internal returns (address) {
        // deploy new osp for eigenda x arbitrum v2.1.3
        // and override existing insecure one!
        address osp;
        {
            address osp0 = deployBytecodeFromJSON(
                "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/osp/OneStepProver0.sol/OneStepProver0.json"
            );
            address ospMemory = deployBytecodeFromJSON(
                "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/osp/OneStepProverMemory.sol/OneStepProverMemory.json"
            );
            address ospMath = deployBytecodeFromJSON(
                "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/osp/OneStepProverMath.sol/OneStepProverMath.json"
            );
            address ospHostIo = deployBytecodeFromJSON(
                "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/osp/OneStepProverHostIo.sol/OneStepProverHostIo.json"
            );
            osp = deployBytecodeWithConstructorFromJSON(
                "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/osp/OneStepProofEntry.sol/OneStepProofEntry.json",
                abi.encode(osp0, ospMemory, ospMath, ospHostIo)
            );
        }

        return osp;
    }

    function run() public {
        // env ingestion
        bool isArbitrum = vm.envBool("PARENT_CHAIN_IS_ARBITRUM");
        uint256 maxDataSize = vm.envUint("MAX_DATA_SIZE");
        address eigenDACertVerifier = vm.envAddress("EIGENDA_CERT_VERIFIER");

        uint256 parentChainID = block.chainid;
        if ((parentChainID == 17000 || parentChainID == 1) && (eigenDACertVerifier == address(0))) {
            // holesky or ETH (i.e, where EigenDA cert verification is actually possible!)
            console.log(
                "Deploying migration action with no EigenDA cert verifier"
                "on a chain where EigenDA certs can be verified!. This will result in a trust assumption for any"
                "rollup who calls this action; unless they manually call setEigenDACertVerifier to update the rollup's"
                "sequencer inbox to do actual verification."
            );
        }

        if (isArbitrum) {
            // etch a mock ArbSys contract so that foundry simulate it nicely
            bytes memory mockArbSysCode = address(new MockArbSys()).code;
            vm.etch(address(100), mockArbSysCode);
        }

        vm.startBroadcast();

        address reader4844Address;
        if (!isArbitrum) {
            // deploy blob reader
            reader4844Address = deployBytecodeFromJSON(
                "/node_modules/@eigenda/nitro-contracts-2.1.3/out/yul/Reader4844.yul/Reader4844.json"
            );
        }

        // deploy new ETHInbox contract from v2.1.3
        address newEthInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/Inbox.sol/Inbox.json",
            abi.encode(maxDataSize)
        );

        // deploy new ERC20Inbox contract from v2.1.3
        address newERC20InboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/ERC20Inbox.sol/ERC20Inbox.json",
            abi.encode(maxDataSize)
        );

        // deploy new EthSequencerInbox contract from v2.1.3
        address newEthSeqInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/SequencerInbox.sol/SequencerInbox.json",
            abi.encode(maxDataSize, reader4844Address, false)
        );

        // deploy new Erc20SequencerInbox contract from v2.1.3
        address newErc20SeqInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/SequencerInbox.sol/SequencerInbox.json",
            abi.encode(maxDataSize, reader4844Address, true)
        );

        // deploy new one step prover from v2.1.3
        address newOsp = deployOSPEigenDAV2Point1Point3Impl();

        // deploy new challenge manager from v2.1.3
        address newChallengeManager = deployBytecodeFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/challenge/ChallengeManager.sol/ChallengeManager.json"
        );

        // deploy upgrade action
        new NitroContractsEigenDA2Point1Point3UpgradeAction(
            newEthInboxImpl,
            newERC20InboxImpl,
            newEthSeqInboxImpl,
            newErc20SeqInboxImpl,
            newChallengeManager,
            eigenDACertVerifier,
            IOneStepProofEntry(newOsp),
            WASM_MODULE_ROOT
        );

        vm.stopBroadcast();
    }
}
