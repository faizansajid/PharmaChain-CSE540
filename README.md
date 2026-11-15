# PharmaChain

PharmaChain tracks a drug batch from the manufacturer to the pharmacy. The Solidity contract records batch registration, custody transfers, cold-chain results, regulator verification, dispensing, and recalls. Temperature logs and certificates are intended to stay off-chain on IPFS; the contract stores their CIDs and hashes but does not upload files.

This repository contains the draft contract and a local Hardhat demo of the main batch lifecycle. The Web3 interface, IPFS uploader, simulated sensor script, and Polygon Amoy deployment are still planned work.

## Files

- `contracts/BatchRegistry.sol` - batch records, roles, custody transfers, cold-chain results, verification, and recalls.
- `scripts/demo.js` - deploys to a temporary local chain and demonstrates the manufacturer-to-distributor-to-pharmacy flow.
- `hardhat.config.js` - Solidity compiler and ethers plugin configuration.

## Run the local demo

Requirements: Node.js 20 or newer and npm.

From the repository root, run:

```bash
npm install
npm run demo
```

The script starts a temporary local Hardhat chain, deploys `BatchRegistry`, assigns manufacturer, distributor, pharmacy, and regulator roles, and runs a passing shipment flow. It prints each confirmed action and the final batch state (`Dispensed`) with the custody record count. The IPFS CIDs are placeholders; the script does not upload files or deploy to Polygon Amoy.

For the interim demo recording, run `npm run demo` while screen sharing. Explain which stakeholder signer performs each transaction. This is a local development chain, not the public Polygon Amoy testnet.

## Planned testnet deployment

Polygon Amoy (chain ID `80002`) is the planned public test network. A deployment there needs an RPC endpoint, a funded test wallet, and a deployment script. Never commit a private key. The contract constructor takes the consortium admin address; that address can assign manufacturer, distributor, pharmacy, and regulator roles with OpenZeppelin's `grantRole` function.

## How the draft works

1. A manufacturer registers a batch with a unique `bytes32` batch ID and a metadata CID and hash. Its state is `Manufactured`.
2. The current custodian calls `transferCustody` to start a handoff to an authorized distributor or pharmacy. The state changes to `Shipped`.
3. The current custodian calls `logColdChain` with a log CID, hash, and pass/fail result. A log is required for each shipment leg.
4. The recipient calls `confirmReceipt`, becoming the current custodian. The state changes to `Received`.
5. When the batch reaches a pharmacy, a regulator calls `verifyBatch`. If a cold-chain check failed, the regulator must approve an exception.
6. The pharmacy can call `markDispensed` after verification.
7. A regulator can call `recallBatch` at any point before an earlier recall.

The `getBatch` and `getCustodyHistory` functions provide read access to batch details and custody history. Events emitted by the current contract are `BatchRegistered`, `CustodyTransferred`, `BatchReceived`, `ColdChainLogged`, `BatchVerified`, `BatchDispensed`, and `BatchRecalled`.

## Scope

The current repository contains the contract draft and local demo only. The project plan also includes a simulated IoT temperature feed, IPFS evidence, a Web3 interface, and evaluation on Polygon Amoy. It does not include real IoT hardware, payments, drug master data, GS1/EPCIS integration, or zero-knowledge privacy.

This is a course prototype. Do not use it for real pharmaceutical shipments without further implementation and review. Do not store patient details or full documents on-chain.
