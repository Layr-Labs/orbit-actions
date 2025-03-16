// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import {DeploymentHelpersScript} from "../../helper/DeploymentHelpers.s.sol";
import {
    NitroContractsEigenDA2Point1Point3UpgradeAction,
    IOneStepProofEntry
} from "../../../../contracts/parent-chain/contract-upgrades/NitroContractsEigenDA2Point1Point3UpgradeAction.sol";
import {MockArbSys} from "../../helper/MockArbSys.sol";

/**
 * @title DeployNitroContractsEigenDA2Point1Point3UpgradeActionScript
 * @notice This script deploys the ERC20Bridge contract and NitroContractsEigenDA2Point1Point3UpgradeAction contract.
 */
contract DeployNitroContractsEigenDA2Point1Point3UpgradeActionScript is DeploymentHelpersScript {
    // ArbOS x EigenDA v32 https://github.com/Layr-Labs/nitro/releases/tag/consensus-eigenda-v32.1
    bytes32 public constant WASM_MODULE_ROOT = 0x04a297cdd13254c4c6c26388915d416286daf22f3a20e3ebee10400a3129dd17;
    // ArbOS v32 https://github.com/OffchainLabs/nitro/releases/tag/consensus-v32
    bytes32 public constant COND_WASM_MODULE_ROOT = 0x184884e1eb9fefdc158f6c8ac912bb183bf3cf83f0090317e0bc4ac5860baa39;

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
        bool isArbitrum = vm.envBool("PARENT_CHAIN_IS_ARBITRUM");
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
            abi.encode(vm.envUint("MAX_DATA_SIZE"))
        );
        // deploy new ERC20Inbox contract from v2.1.3
        address newERC20InboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/ERC20Inbox.sol/ERC20Inbox.json",
            abi.encode(vm.envUint("MAX_DATA_SIZE"))
        );

        // deploy new EthSequencerInbox contract from v2.1.3
        address newEthSeqInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/SequencerInbox.sol/SequencerInbox.json",
            abi.encode(vm.envUint("MAX_DATA_SIZE"), reader4844Address, false)
        );

        // deploy new Erc20SequencerInbox contract from v2.1.3
        address newErc20SeqInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/SequencerInbox.sol/SequencerInbox.json",
            abi.encode(vm.envUint("MAX_DATA_SIZE"), reader4844Address, true)
        );

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
            IOneStepProofEntry(newOsp),
            WASM_MODULE_ROOT,
            COND_WASM_MODULE_ROOT
        );

        vm.stopBroadcast();
    }
}
