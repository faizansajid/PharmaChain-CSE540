# PharmaChain Interim Demo Runbook

Target length: about 5 minutes. Record the screen and narration in Zoom. Keep the repository open so the demo and code walkthrough are visible.

## Before recording

1. From the repository root, run `npm install` once.
2. Run `npm run demo` once to make sure dependencies and Solidity compilation are ready.
3. Start the Zoom recording, then run `npm run demo` again on screen.
4. Keep the updated slides ready. The Hardhat demo uses a temporary local chain, not Polygon Amoy. Its IPFS CIDs are placeholders and it does not upload files.

## Timed narration

### 0:00–0:40 — Project and current status

“Our project is PharmaChain. We’re designing a blockchain-based record for pharmaceutical batches as they move from a manufacturer to a distributor and pharmacy. The current repository has the Solidity `BatchRegistry` contract and a local Hardhat demo. The Web3 interface, IPFS uploader, simulated sensor feed, and Polygon Amoy deployment are still in progress.”

### 0:40–1:00 — What the demo represents

“I’m going to run the contract on a temporary local Hardhat chain. The script deploys the contract, assigns manufacturer, distributor, pharmacy, and regulator roles, and then runs a passing batch flow. The addresses and IPFS CIDs are demo values.”

### 1:00–3:15 — Run the workflow

Run `npm run demo` and point to each output line as it appears:

- The admin grants the four roles.
- The manufacturer registers a batch.
- The manufacturer transfers it to a distributor, records a passing cold-chain result, and the distributor confirms receipt.
- The distributor transfers it to a pharmacy, records the next passing result, and the pharmacy confirms receipt.
- The regulator verifies the batch; the pharmacy marks it dispensed.
- The final read shows `Dispensed`, the pharmacy as custodian, and two custody records.

Say that each confirmed line represents a transaction accepted by the local chain. The contract emits events for registration, transfers, receipt, cold-chain logs, verification, and dispensing.

### 3:15–4:10 — High-level code walkthrough

Open `contracts/BatchRegistry.sol`. Show the `State` enum and `Batch` struct, then point to `registerBatch`, `transferCustody`, `logColdChain`, `confirmReceipt`, `verifyBatch`, and `markDispensed`. Explain that role checks and current-custodian checks protect state-changing actions. Open `scripts/demo.js` briefly to show that different Hardhat signers call those functions as different stakeholders.

### 4:10–4:50 — Remaining work and close

“The next work is the Web3 interface, IPFS evidence flow, simulated temperature feed, and deployment to Polygon Amoy. We also plan to evaluate gas, latency, authorization failures, invalid lifecycle actions, and tampered evidence. Our final video, repository, and report are due December 4. This local demo shows the contract flow we have working now; the remaining pieces will connect it to the full prototype.”

## Submission reminder

Review the recording, confirm it is 4:30–5:30, and check audio and screen readability. Upload a `.txt` file to Canvas containing the Zoom recording link and passcode.
