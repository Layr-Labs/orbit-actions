# Nitro contracts 2.1.3 upgrade

> [!CAUTION]
> This is a patch version and is necessary for all EigenDA x Arbitrum chains as it includes many critical bug fixes including EIP-7702 vulnerability patches.
>

These scripts deploy and execute the `NitroContractsEigenDA2Point1Point3UpgradeAction` contract which allows existing Arbitrum Orbit chains as well EigenDA Orbit chains to upgrade to [v2.1.3 release](https://github.com/layr-labs/nitro-contracts/releases/tag/v2.1.3). Pre-deployed instances of the upgrade action exist on the chains listed in the following section.

Upgrading to `eigenda-v2.1.3` is required to ensure post-pectra compatibility.

`NitroContractsEigenDA2Point1Point3UpgradeAction` will perform the following actions based on who is calling it:

**Vanilla Arbitrum Chain using [v2.1.3](https://github.com/OffchainLabs/nitro-contracts/releases/tag/v2.1.3)**
i.e (`IS_EIGENDA_V2_1_0_CALLER=false`)
1. Upgrade the `SequencerInbox` contract to `eigenda-v2.1.3`
2. Upgrade the `ChallengerManager` contract to `eigenda-v2.1.3`
3. Set a new `EigenDACertVerifier` contract into the `SequencerInbox` overriding the existing and now deprecated `EigenDARollupManager` contract

**EigenDA Arbitrum Chain using [v2.1.0](https://github.com/Layr-Labs/nitro-contracts/releases/tag/v2.1.0)**
i.e (`IS_EIGENDA_V2_1_0_CALLER=true`)
1. Upgrade the `Inbox` or `ERC20Inbox` contract to `eigenda-v2.1.3`
2. Upgrade the `SequencerInbox` contract to `eigenda-v2.1.3`
3. Upgrade the `ChallengerManager` contract to `eigenda-v2.1.3` 
4. Set a new `EigenDACertVerifier` contract into the `SequencerInbox` overriding the existing and now deprecated `EigenDARollupManager` contract

## Requirements
This upgrade assumes the caller contract set is either running `eigenda-v2.1.0` or vanilla arbitrum `v2.1.3` contracts. The use of other versions
could result in unintended side effects and is untested.

Please refer to the top [README](/README.md#check-version-and-upgrade-path) `Check Version and Upgrade Path` on how to determine your current nitro contracts version.

## Deployed instances

### Mainnets
- L1 Mainnet: N/A
- L2 Arb1: N/A
- L2 Base: N/A

### Testnets ([consensus-v32.1](https://github.com/Layr-Labs/nitro/releases/tag/consensus-eigenda-v32.1))
**NOT RECOMMENDED FOR USE - PLEASE USE consensus-v32.3**
- L1 Sepolia: N/A
- L1 Holesky: [0x31C2C3dd9C47049a975DFaE804C886333CDCF9BB](https://holesky.etherscan.io/address/0x31c2c3dd9c47049a975dfae804c886333cdcf9bb)
- L2 ArbSepolia: [0xc5d5c28F94c95D851a42Ff97f1886f8af505BD04](https://sepolia.arbiscan.io/address/0xc5d5c28F94c95D851a42Ff97f1886f8af505BD04)
- L2 BaseSepolia: [0xbda5cff32ce4b2a1e312439e21d1b163d48b0936](https://sepolia.basescan.org/address/0xbda5cff32ce4b2a1e312439e21d1b163d48b0936)

### Testnets ([consensus-v32.3](https://github.com/Layr-Labs/nitro/releases/tag/consensus-eigenda-v32.3))
- **L1 Sepolia**: [0x8b4b9BA6715aB493073d9e8426f3E9eb8404f12a](https://sepolia.etherscan.io/address/0x8b4b9BA6715aB493073d9e8426f3E9eb8404f12a)  
  - ParentChainIsArbitrum: `false`  
  - MaxDataSize: `117964`
  - EigenDACertVerification: `true`

- **L2 ArbSepolia**: [0xf099152D84dd3473442Ee659276b6d374c008c5a](https://sepolia.arbiscan.io/address/0xf099152D84dd3473442Ee659276b6d374c008c5a)  
  - ParentChainIsArbitrum: `true`  
  - MaxDataSize: `104857`
  - EigenDACertVerification: `false`

- **L2 BaseSepolia**: [0x28303a297e31ac5376047b128867e9D339B58Bf0](https://sepolia.basescan.org/address/0x28303a297e31ac5376047b128867e9D339B58Bf0#code)  
  - ParentChainIsArbitrum: `false`  
  - MaxDataSize: `104857`
  - EigenDACertVerification: `true`

## How to use it

1. Setup .env according to the example files, make sure you have everything correctly defined. The .env file must be in project root for recent foundry versions.

> [!CAUTION]
> The `.env` file must be in project root.

If migrating from an existing Arbirum orbit chain using nitro-contracts v2.1.3, set:
```
IS_EIGENDA_V2_1_0_CALLER=false
```

if migrating from an existing Arbitrum x EigenDA chain using nitro-contracts v2.1.0, set:
```
IS_EIGENDA_V2_1_0_CALLER=true
```

2. (Skip this step if you can use the deployed instances of action contract)
   `DeployNitroContractsEigenDA2Point1Point3UpgradeActionScript.s.sol` script deploys templates, and upgrade action itself. It can be executed in this directory like this:

```bash
forge script --sender $DEPLOYER --rpc-url $PARENT_CHAIN_RPC --broadcast --slow DeployNitroContractsEigenDA2Point1Point3UpgradeActionScript -vvv --verify --skip-simulation
# use --account XXX / --private-key XXX / --interactive / --ledger to set the account to send the transaction from
```

As a result, all templates and upgrade action are deployed. Note the last deployed address - that's the upgrade action.

3. `ExecuteNitroContracts2Point1Point3Upgrade.s.sol` script uses previously deployed upgrade action to execute the upgrade. It makes following assumptions - L1UpgradeExecutor is the rollup owner, and there is an EOA which has executor rights on the L1UpgradeExecutor. Proceed with upgrade using the owner account (the one with executor rights on L1UpgradeExecutor):

```bash
forge script --sender $EXECUTOR --rpc-url $PARENT_CHAIN_RPC --broadcast ExecuteNitroContractsEigenDA2Point1Point3UpgradeScript -vvv
# use --account XXX / --private-key XXX / --interactive / --ledger to set the account to send the transaction from
```

If you have a multisig as executor, you can still run the above command without broadcasting to get the payload for the multisig transaction.

4. That's it, upgrade has been performed. You can make sure it has successfully executed by checking the native token decimals.

```bash
# should return 18
cast call --rpc-url $PARENT_CHAIN_RPC $BRIDGE "nativeTokenDecimals()(uint8)"
```

## FAQ

### Q: intrinsic gas too low when running foundry script

A: try to add -g 1000 to the command
