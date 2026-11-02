# PharmaChain

PharmaChain is a project about tracking a drug batch from the manufacturer to the pharmacy. The proposed system uses a Solidity contract on Polygon Amoy to record batch registration, custody transfers, cold-chain results, regulator verification, and recalls. Temperature logs and certificates stay off-chain on IPFS; the contract stores their CIDs and hashes.

This repository contains the draft contract for the project. The web interface and simulated sensor script are part of the larger design, but are not included in this draft.

## Files

- `contracts/BatchRegistry.sol` - batch records, roles, custody transfers, cold-chain results, verification, and recalls.

## Dependencies

- Solidity `0.8.24` or newer `0.8.x` compiler
- OpenZeppelin Contracts `5.x` for `AccessControl`
- Remix or Hardhat for compiling and deploying
- Polygon Amoy testnet for the planned deployment (chain ID `80002`)
- IPFS for off-chain files

## Setup

1. Download or clone this repository.
2. In Remix, open `contracts/BatchRegistry.sol` and select Solidity `0.8.24` or a newer `0.8.x` compiler. For Hardhat, add the file to a Hardhat project and install OpenZeppelin Contracts with `npm install @openzeppelin/contracts`.
3. Deploy to a local chain first. For a testnet deployment, configure Polygon Amoy and use test POL for gas.
4. Pass the consortium admin address to the constructor. That address can assign manufacturer, distributor, pharmacy, and regulator roles with OpenZeppelin's `grantRole` function.

## How the draft works

1. A manufacturer registers a batch with a unique batch ID and a metadata CID and hash. Its state is `Manufactured`.
2. The current custodian calls `transferCustody` to send it to an authorized distributor or pharmacy. The state changes to `Shipped`.
3. The current custodian records the simulated temperature log CID, hash, and pass/fail result with `logColdChain`. A log is required for each shipment leg.
4. The recipient calls `confirmReceipt`, becoming the current custodian. The state changes to `Received`.
5. When the batch reaches a pharmacy, a regulator calls `verifyBatch`. If a cold-chain check failed, the regulator must approve an exception.
6. The pharmacy can call `markDispensed` after verification.
7. A regulator can call `recallBatch` at any point in the lifecycle.

The `getBatch` and `getCustodyHistory` functions provide read access to current batch details and custody history. Cold-chain records are emitted as events, so an application can read them from transaction logs.

## Scope

The draft covers the contract design only. The project plan also includes a simulated IoT temperature feed, IPFS evidence, a Web3 interface, and evaluation on Polygon Amoy. It does not include real IoT hardware, payments, drug master data, GS1/EPCIS integration, or zero-knowledge privacy.

This is a course prototype. Do not use it for real pharmaceutical shipments without further implementation and review. Do not store patient details or full documents on-chain.
