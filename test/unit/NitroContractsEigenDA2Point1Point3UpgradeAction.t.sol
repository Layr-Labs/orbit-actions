// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Test.sol";

import {Bridge, IOwnable} from "@arbitrum/nitro-contracts-2.1.2/src/bridge/Bridge.sol";

import {
    ERC20Bridge as ERC20Bridge_2_1_3,
    IOwnable as IOwnable_2_1_3
} from "@arbitrum/nitro-contracts-2.1.3/src/bridge/ERC20Bridge.sol";
import {
    ERC20Bridge as ERC20Bridge_2_1_0_EigenDA,
    IOwnable as IOwnable_2_1_0_EigenDA
} from "@eigenda/nitro-contracts-2.1.0/src/bridge/ERC20Bridge.sol";
import {Bridge as Bridge_2_1_3} from "@arbitrum/nitro-contracts-2.1.3/src/bridge/Bridge.sol";
import {Bridge as Bridge_2_1_0_EigenDA} from "@eigenda/nitro-contracts-2.1.0/src/bridge/Bridge.sol";
import {
    ChallengeManager as ChallengerManager_2_1_3,
    IChallengeManager as IChallengeManager_2_1_3
} from "@arbitrum/nitro-contracts-2.1.3/src/challenge/ChallengeManager.sol";
import {
    ChallengeManager as ChallengerManager_2_1_0_EigenDA,
    IChallengeManager as IChallengeManager_2_1_0_EigenDA
} from "@eigenda/nitro-contracts-2.1.0/src/challenge/ChallengeManager.sol";
import {ERC20Inbox as ERC20Inbox_2_1_3} from "@arbitrum/nitro-contracts-2.1.3/src/bridge/ERC20Inbox.sol";
import {ERC20Inbox as ERC20Inbox_2_1_0_EigenDA} from "@eigenda/nitro-contracts-2.1.0/src/bridge/ERC20Inbox.sol";

import {
    Inbox as Inbox_2_1_3, IInboxBase as IInboxBase_2_1_3
} from "@arbitrum/nitro-contracts-2.1.3/src/bridge/Inbox.sol";
import {
    Inbox as Inbox_2_1_0_EigenDA,
    IInboxBase as IInboxBase_2_1_0_EigenDA
} from "@eigenda/nitro-contracts-2.1.0/src/bridge/Inbox.sol";

import {
    SequencerInbox as SequencerInbox_2_1_3,
    ISequencerInbox as ISequencerInbox_2_1_3
} from "@arbitrum/nitro-contracts-2.1.3/src/bridge/SequencerInbox.sol";
import {
    SequencerInbox as SequencerInbox_2_1_0_EigenDA,
    ISequencerInbox as ISequencerInbox_2_1_0_EigenDA
} from "@eigenda/nitro-contracts-2.1.0/src/bridge/SequencerInbox.sol";

import {IReader4844 as IReader4844_2_1_3} from "@arbitrum/nitro-contracts-2.1.3/src/libraries/IReader4844.sol";
import {IReader4844 as IReader4844_2_1_0_EigenDA} from "@eigenda/nitro-contracts-2.1.0/src/libraries/IReader4844.sol";

import {ERC20Bridge as ERC20Bridge_1_3_0} from "@arbitrum/nitro-contracts-1.3.0/src/bridge/ERC20Bridge.sol";

import {
    NitroContractsEigenDA2Point1Point3UpgradeAction,
    UpgradeSource,
    IOneStepProofEntry
} from "contracts/parent-chain/contract-upgrades/NitroContractsEigenDA2Point1Point3UpgradeAction.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IUpgradeExecutor} from "@offchainlabs/upgrade-executor/src/IUpgradeExecutor.sol";
import {DeploymentHelpersScript} from "../../scripts/foundry/helper/DeploymentHelpers.s.sol";

interface IUpgradeExecutorExtended is IUpgradeExecutor {
    function initialize(address admin, address[] memory executors) external;
}

contract FakeToken {
    uint256 public decimals = 18;

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }
}

contract FakeArbitrumEigenDA2Point1Point0Rollup {
    IChallengeManager_2_1_0_EigenDA public challengeManager;
    bytes32 public wasmModuleRoot;

    constructor(IChallengeManager_2_1_0_EigenDA _challengeManager, bytes32 _wasmModuleRoot) {
        challengeManager = _challengeManager;
        wasmModuleRoot = _wasmModuleRoot;
    }

    function setWasmModuleRoot(bytes32 newWasmModuleRoot) external {
        wasmModuleRoot = newWasmModuleRoot;
    }
}

contract FakeArbitrum2Point1Point3Rollup {
    IChallengeManager_2_1_3 public challengeManager;
    bytes32 public wasmModuleRoot;

    constructor(IChallengeManager_2_1_3 _challengeManager, bytes32 _wasmModuleRoot) {
        challengeManager = _challengeManager;
        wasmModuleRoot = _wasmModuleRoot;
    }

    function setWasmModuleRoot(bytes32 newWasmModuleRoot) external {
        wasmModuleRoot = newWasmModuleRoot;
    }
}

contract NitroContractsEigenDA2Point1Point3UpgradeActionTest is Test, DeploymentHelpersScript {
    // ArbOS x EigenDA v32 https://github.com/Layr-Labs/nitro/releases/tag/consensus-eigenda-v32
    bytes32 public constant WASM_MODULE_ROOT = 0x951009942c00b5bd0abec233174fe33fadf7cd5013d17b042f9b28b3b00b469c;
    // ArbOS v32 https://github.com/OffchainLabs/nitro/releases/tag/consensus-v32
    bytes32 public constant COND_WASM_MODULE_ROOT = 0x184884e1eb9fefdc158f6c8ac912bb183bf3cf83f0090317e0bc4ac5860baa39;

    uint256 maxDataSize = 100_000; // dummy value

    IUpgradeExecutorExtended upgradeExecutor;

    address fakeToken;

    ProxyAdmin proxyAdmin;

    address fakeRollup;
    address fakeReader = address(0xFF01);

    address erc20Bridge_2_1_3;
    address bridge_2_1_3;
    address erc20SequencerInbox_2_1_3;
    address sequencerInbox_2_1_3;
    address erc20Inbox_2_1_3;
    address inbox_2_1_3;
    address challengeManager_2_1_3;
    FakeArbitrum2Point1Point3Rollup fakeRollup_2_1_3;

    address erc20Bridge_2_1_0_EIGENDA;
    address bridge_2_1_0_EIGENDA;
    address erc20SequencerInbox_2_1_0_EIGENDA;
    address sequencerInbox_2_1_0_EIGENDA;
    address erc20Inbox_2_1_0_EIGENDA;
    address inbox_2_1_0_EIGENDA;
    address challengeManager_2_1_0_EIGENDA;
    FakeArbitrumEigenDA2Point1Point0Rollup fakeRollup_2_1_0_EIGENDA;

    address newEthInboxImpl;
    address newERC20InboxImpl;
    address newEthSeqInboxImpl;
    address newErc20SeqInboxImpl;
    address newChallengeManager;
    address newOneStepProver;

    function setUp() public {
        // deploy a proxy admin
        proxyAdmin = new ProxyAdmin();

        // deploy an upgrade executor
        address[] memory execs = new address[](1);
        execs[0] = address(this);
        upgradeExecutor = IUpgradeExecutorExtended(
            address(
                new TransparentUpgradeableProxy(
                    deployBytecodeFromJSON(
                        "/node_modules/@offchainlabs/upgrade-executor/build/contracts/src/UpgradeExecutor.sol/UpgradeExecutor.json"
                    ),
                    address(proxyAdmin),
                    ""
                )
            )
        );
        upgradeExecutor.initialize(address(this), execs);

        proxyAdmin.transferOwnership(address(upgradeExecutor));

        // deploy a fake token
        fakeToken = address(new FakeToken());

        // deploy an ERC20Bridge on v2.1.3
        erc20Bridge_2_1_3 =
            address(new TransparentUpgradeableProxy(address(new ERC20Bridge_2_1_3()), address(proxyAdmin), ""));

        // deploy an ETH Bridge on v2.1.3
        bridge_2_1_3 = address(new TransparentUpgradeableProxy(address(new Bridge_2_1_3()), address(proxyAdmin), ""));

        // deploy an ERC20 SequencerInbox on v2.1.3
        erc20SequencerInbox_2_1_3 = address(
            new TransparentUpgradeableProxy(
                address(new SequencerInbox_2_1_3(maxDataSize, IReader4844_2_1_3(fakeReader), true)),
                address(proxyAdmin),
                ""
            )
        );

        // deploy an ETH SequencerInbox on v2.1.3
        sequencerInbox_2_1_3 = address(
            new TransparentUpgradeableProxy(
                address(new SequencerInbox_2_1_3(maxDataSize, IReader4844_2_1_3(fakeReader), false)),
                address(proxyAdmin),
                ""
            )
        );

        // deploy an ERC20Inbox on v2.1.3
        erc20Inbox_2_1_3 = address(
            new TransparentUpgradeableProxy(address(new ERC20Inbox_2_1_3(maxDataSize)), address(proxyAdmin), "")
        );

        // deploy an ETH Inbox on v2.1.3
        inbox_2_1_3 =
            address(new TransparentUpgradeableProxy(address(new Inbox_2_1_3(maxDataSize)), address(proxyAdmin), ""));

        // deploy a challenge manager on v2.1.3
        challengeManager_2_1_3 =
            address(new TransparentUpgradeableProxy(address(new ChallengerManager_2_1_3()), address(proxyAdmin), ""));

        fakeRollup_2_1_3 =
            new FakeArbitrum2Point1Point3Rollup(IChallengeManager_2_1_3(challengeManager_2_1_3), COND_WASM_MODULE_ROOT);

        // initialize everything
        Bridge_2_1_3(bridge_2_1_3).initialize(IOwnable_2_1_3(address(fakeRollup)));
        ERC20Bridge_2_1_3(erc20Bridge_2_1_3).initialize(IOwnable_2_1_3(address(fakeRollup)), fakeToken);
        SequencerInbox_2_1_3(sequencerInbox_2_1_3).initialize(
            Bridge_2_1_3(bridge_2_1_3), ISequencerInbox_2_1_3.MaxTimeVariation(10, 10, 10, 10)
        );
        SequencerInbox_2_1_3(erc20SequencerInbox_2_1_3).initialize(
            Bridge_2_1_3(erc20Bridge_2_1_3), ISequencerInbox_2_1_3.MaxTimeVariation(10, 10, 10, 10)
        );
        Inbox_2_1_3(inbox_2_1_3).initialize(Bridge_2_1_3(bridge_2_1_3), SequencerInbox_2_1_3(sequencerInbox_2_1_3));
        ERC20Inbox_2_1_3(erc20Inbox_2_1_3).initialize(
            Bridge_2_1_3(erc20Bridge_2_1_3), SequencerInbox_2_1_3(erc20SequencerInbox_2_1_3)
        );

        // eigenda v2.1.0
        // deploy an ERC20Bridge on eigenda v2.1.0
        erc20Bridge_2_1_0_EIGENDA =
            address(new TransparentUpgradeableProxy(address(new ERC20Bridge_2_1_0_EigenDA()), address(proxyAdmin), ""));

        // deploy an ETH Bridge on eigenda v2.1.0
        bridge_2_1_0_EIGENDA =
            address(new TransparentUpgradeableProxy(address(new Bridge_2_1_0_EigenDA()), address(proxyAdmin), ""));

        // deploy an ERC20 SequencerInbox on eigenda v2.1.0
        erc20SequencerInbox_2_1_0_EIGENDA = address(
            new TransparentUpgradeableProxy(
                address(new SequencerInbox_2_1_0_EigenDA(maxDataSize, IReader4844_2_1_0_EigenDA(fakeReader), true)),
                address(proxyAdmin),
                ""
            )
        );

        // deploy an ETH SequencerInbox on eigenda v2.1.0
        sequencerInbox_2_1_0_EIGENDA = address(
            new TransparentUpgradeableProxy(
                address(new SequencerInbox_2_1_0_EigenDA(maxDataSize, IReader4844_2_1_0_EigenDA(fakeReader), false)),
                address(proxyAdmin),
                ""
            )
        );

        // deploy an ERC20Inbox on eigenda v2.1.0
        erc20Inbox_2_1_0_EIGENDA = address(
            new TransparentUpgradeableProxy(address(new ERC20Inbox_2_1_0_EigenDA(maxDataSize)), address(proxyAdmin), "")
        );

        // deploy an ETH Inbox on eigenda v2.1.0
        inbox_2_1_0_EIGENDA = address(
            new TransparentUpgradeableProxy(address(new Inbox_2_1_0_EigenDA(maxDataSize)), address(proxyAdmin), "")
        );

        // deploy a challenge manager on eigenda v2.1.0
        challengeManager_2_1_0_EIGENDA = address(
            new TransparentUpgradeableProxy(address(new ChallengerManager_2_1_0_EigenDA()), address(proxyAdmin), "")
        );

        fakeRollup_2_1_0_EIGENDA = new FakeArbitrumEigenDA2Point1Point0Rollup(
            IChallengeManager_2_1_0_EigenDA(challengeManager_2_1_0_EIGENDA), WASM_MODULE_ROOT
        );

        // initialize everything
        Bridge_2_1_0_EigenDA(bridge_2_1_0_EIGENDA).initialize(IOwnable_2_1_0_EigenDA(address(fakeRollup)));
        ERC20Bridge_2_1_0_EigenDA(erc20Bridge_2_1_0_EIGENDA).initialize(
            IOwnable_2_1_0_EigenDA(address(fakeRollup)), fakeToken
        );
        SequencerInbox_2_1_0_EigenDA(sequencerInbox_2_1_0_EIGENDA).initialize(
            Bridge_2_1_0_EigenDA(bridge_2_1_0_EIGENDA), ISequencerInbox_2_1_0_EigenDA.MaxTimeVariation(10, 10, 10, 10)
        );
        SequencerInbox_2_1_0_EigenDA(erc20SequencerInbox_2_1_0_EIGENDA).initialize(
            Bridge_2_1_0_EigenDA(erc20Bridge_2_1_0_EIGENDA),
            ISequencerInbox_2_1_0_EigenDA.MaxTimeVariation(10, 10, 10, 10)
        );
        Inbox_2_1_0_EigenDA(inbox_2_1_0_EIGENDA).initialize(
            Bridge_2_1_0_EigenDA(bridge_2_1_0_EIGENDA), SequencerInbox_2_1_0_EigenDA(sequencerInbox_2_1_0_EIGENDA)
        );
        ERC20Inbox_2_1_0_EigenDA(erc20Inbox_2_1_0_EIGENDA).initialize(
            Bridge_2_1_0_EigenDA(erc20Bridge_2_1_0_EIGENDA),
            SequencerInbox_2_1_0_EigenDA(erc20SequencerInbox_2_1_0_EIGENDA)
        );
    }

    // copied from deployment script
    function _deployActionScript() internal returns (NitroContractsEigenDA2Point1Point3UpgradeAction) {
        bool isArbitrum = false;
        address reader4844Address;
        if (!isArbitrum) {
            // deploy blob reader
            reader4844Address = deployBytecodeFromJSON(
                "/node_modules/@eigenda/nitro-contracts-2.1.3/out/yul/Reader4844.yul/Reader4844.json"
            );
        }

        // deploy new ETHInbox contract from v2.1.3
        newEthInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/Inbox.sol/Inbox.json",
            abi.encode(maxDataSize)
        );
        // deploy new ERC20Inbox contract from v2.1.3
        newERC20InboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/ERC20Inbox.sol/ERC20Inbox.json",
            abi.encode(maxDataSize)
        );

        // deploy new EthSequencerInbox contract from v2.1.3
        newEthSeqInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/SequencerInbox.sol/SequencerInbox.json",
            abi.encode(maxDataSize, reader4844Address, false)
        );

        // deploy new Erc20SequencerInbox contract from v2.1.3
        newErc20SeqInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/bridge/SequencerInbox.sol/SequencerInbox.json",
            abi.encode(maxDataSize, reader4844Address, true)
        );

        // deploy new challenge manager from v2.1.3
        newChallengeManager = deployBytecodeFromJSON(
            "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/challenge/ChallengeManager.sol/ChallengeManager.json"
        );

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
            newOneStepProver = deployBytecodeWithConstructorFromJSON(
                "/node_modules/@eigenda/nitro-contracts-2.1.3/build/contracts/src/osp/OneStepProofEntry.sol/OneStepProofEntry.json",
                abi.encode(osp0, ospMemory, ospMath, ospHostIo)
            );
        }

        // deploy upgrade action
        return new NitroContractsEigenDA2Point1Point3UpgradeAction(
            newEthInboxImpl,
            newERC20InboxImpl,
            newEthSeqInboxImpl,
            newErc20SeqInboxImpl,
            newChallengeManager,
            IOneStepProofEntry(newOneStepProver),
            WASM_MODULE_ROOT,
            COND_WASM_MODULE_ROOT
        );
    }

    function testArb2_1_3toEigenDA2_1_3_NativeTokenBridge() public {
        NitroContractsEigenDA2Point1Point3UpgradeAction action = _deployActionScript();
        upgradeExecutor.execute(
            address(action),
            abi.encodeCall(
                action.perform,
                (address(fakeRollup_2_1_3), inbox_2_1_3, proxyAdmin, UpgradeSource.ArbitrumV2Point1Point3)
            )
        );

        // ensure that only eigenda specific contracts have been updated
        assertNotEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(inbox_2_1_3))), newEthInboxImpl
        );
        assertEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(sequencerInbox_2_1_3))),
            newEthSeqInboxImpl
        );

        assertEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(challengeManager_2_1_3))),
            newChallengeManager
        );

        assertEq(address(IChallengeManager_2_1_3(challengeManager_2_1_3).getOsp(bytes32(0x0))), newOneStepProver);
    }

    function testArb2_1_3toEigenDA2_1_3_ERC20Bridge() public {
        NitroContractsEigenDA2Point1Point3UpgradeAction action = _deployActionScript();
        upgradeExecutor.execute(
            address(action),
            abi.encodeCall(
                action.perform,
                (address(fakeRollup_2_1_3), erc20Inbox_2_1_3, proxyAdmin, UpgradeSource.ArbitrumV2Point1Point3)
            )
        );

        // check correctly upgraded
        assertNotEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(erc20Inbox_2_1_3))), newERC20InboxImpl
        );
        assertEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(erc20SequencerInbox_2_1_3))),
            newErc20SeqInboxImpl
        );

        assertEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(challengeManager_2_1_3))),
            newChallengeManager
        );

        assertEq(address(IChallengeManager_2_1_3(challengeManager_2_1_3).getOsp(bytes32(0x0))), newOneStepProver);
    }

    function testArb2_1_3toEigenDA2_1_3_ERC20Below() public {
        // just downgrade the bridge to v1.3.0 to simulate a v1.3.0 chain
        address newImpl = address(new ERC20Bridge_1_3_0());
        vm.prank(address(upgradeExecutor));
        proxyAdmin.upgrade(TransparentUpgradeableProxy(payable(erc20Bridge_2_1_3)), newImpl);

        NitroContractsEigenDA2Point1Point3UpgradeAction action = _deployActionScript();

        vm.expectRevert("NitroContractsEigenDA2Point1Point3UpgradeAction: bridge is an ERC20Bridge below v2.x.x");
        upgradeExecutor.execute(
            address(action),
            abi.encodeCall(
                action.perform,
                (address(fakeRollup_2_1_3), erc20Inbox_2_1_3, proxyAdmin, UpgradeSource.ArbitrumV2Point1Point3)
            )
        );
    }

    function testArbEigenDA2_1_0toEigenDA2_1_3_NativeTokenBridge() public {
        NitroContractsEigenDA2Point1Point3UpgradeAction action = _deployActionScript();
        upgradeExecutor.execute(
            address(action),
            abi.encodeCall(
                action.perform,
                (address(fakeRollup_2_1_0_EIGENDA), inbox_2_1_0_EIGENDA, proxyAdmin, UpgradeSource.EigenDAV2Point1Zero)
            )
        );

        // ensure that only eigenda specific contracts have been updated
        assertEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(inbox_2_1_0_EIGENDA))),
            newEthInboxImpl
        );
        assertEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(sequencerInbox_2_1_0_EIGENDA))),
            newEthSeqInboxImpl
        );
        assertEq(
            proxyAdmin.getProxyImplementation(TransparentUpgradeableProxy(payable(challengeManager_2_1_0_EIGENDA))),
            newChallengeManager
        );

        assertEq(
            address(IChallengeManager_2_1_3(challengeManager_2_1_0_EIGENDA).getOsp(bytes32(0x0))), newOneStepProver
        );
    }

    function testNotInboxRevertWhenEigenDA_2_1_0_ProvidesIncorrectAddress() public {
        NitroContractsEigenDA2Point1Point3UpgradeAction action = _deployActionScript();
        vm.mockCallRevert(
            address(inbox_2_1_0_EIGENDA), abi.encodeWithSelector(IInboxBase_2_1_0_EigenDA.allowListEnabled.selector), ""
        );
        vm.expectRevert("NitroContractsEigenDA2Point1Point3UpgradeAction: inbox is not an inbox");
        upgradeExecutor.execute(
            address(action),
            abi.encodeCall(
                action.perform,
                (address(fakeRollup_2_1_0_EIGENDA), inbox_2_1_0_EIGENDA, proxyAdmin, UpgradeSource.EigenDAV2Point1Zero)
            )
        );
    }

    function testRevertWhenEigenDA_2_1_0_CallingWithArb_2_1_3_Source() public {
        NitroContractsEigenDA2Point1Point3UpgradeAction action = _deployActionScript();
        vm.expectRevert("NitroContractsEigenDA2Point1Point3UpgradeAction: INCORRECT_CALLER_SOURCE");
        upgradeExecutor.execute(
            address(action),
            abi.encodeCall(
                action.perform,
                (
                    address(fakeRollup_2_1_0_EIGENDA),
                    erc20Inbox_2_1_0_EIGENDA,
                    proxyAdmin,
                    UpgradeSource.ArbitrumV2Point1Point3
                )
            )
        );
    }

    function testRevertWhenArbitrum_2_1_3_CallingWithEigenDA_2_1_0_Source() public {
        NitroContractsEigenDA2Point1Point3UpgradeAction action = _deployActionScript();
        vm.expectRevert("NitroContractsEigenDA2Point1Point3UpgradeAction: INCORRECT_CALLER_SOURCE_EIGENDA");
        upgradeExecutor.execute(
            address(action),
            abi.encodeCall(
                action.perform,
                (address(fakeRollup_2_1_3), erc20Inbox_2_1_3, proxyAdmin, UpgradeSource.EigenDAV2Point1Zero)
            )
        );
    }
}
