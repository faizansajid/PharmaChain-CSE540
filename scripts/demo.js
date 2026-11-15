const { ethers } = require("hardhat");

const STATE_NAMES = [
  "Manufactured",
  "Shipped",
  "Received",
  "Verified",
  "Dispensed",
  "Recalled",
];

async function confirm(label, transaction) {
  const receipt = await (await transaction).wait();
  console.log(`${label}: confirmed in block ${receipt.blockNumber}`);
}

async function main() {
  const [admin, manufacturer, distributor, pharmacy, regulator] = await ethers.getSigners();
  const BatchRegistry = await ethers.getContractFactory("BatchRegistry", admin);
  const registry = await BatchRegistry.deploy(admin.address);
  await registry.waitForDeployment();

  console.log("PharmaChain local contract demo");
  console.log(`Network: local Hardhat chain`);
  console.log(`Contract: ${await registry.getAddress()}`);
  console.log(`Manufacturer: ${manufacturer.address}`);
  console.log(`Distributor: ${distributor.address}`);
  console.log(`Pharmacy: ${pharmacy.address}`);
  console.log(`Regulator: ${regulator.address}`);

  await confirm("Grant manufacturer role", registry.grantRole(await registry.MANUFACTURER_ROLE(), manufacturer.address));
  await confirm("Grant distributor role", registry.grantRole(await registry.DISTRIBUTOR_ROLE(), distributor.address));
  await confirm("Grant pharmacy role", registry.grantRole(await registry.PHARMACY_ROLE(), pharmacy.address));
  await confirm("Grant regulator role", registry.grantRole(await registry.REGULATOR_ROLE(), regulator.address));

  const batchId = ethers.id("PHARMACHAIN-DEMO-BATCH-2026");
  const metadataHash = ethers.keccak256(ethers.toUtf8Bytes("demo batch metadata"));
  const firstLogHash = ethers.keccak256(ethers.toUtf8Bytes("shipment leg 1 temperature log"));
  const secondLogHash = ethers.keccak256(ethers.toUtf8Bytes("shipment leg 2 temperature log"));
  const shipmentHash1 = ethers.keccak256(ethers.toUtf8Bytes("shipment evidence 1"));
  const shipmentHash2 = ethers.keccak256(ethers.toUtf8Bytes("shipment evidence 2"));

  console.log(`\nBatch ID: ${batchId}`);
  await confirm(
    "1. Manufacturer registers batch",
    registry.connect(manufacturer).registerBatch(batchId, "ipfs://demo-metadata-cid", metadataHash),
  );

  await confirm(
    "2. Manufacturer starts transfer to distributor",
    registry.connect(manufacturer).transferCustody(batchId, distributor.address, "ipfs://demo-shipment-1", shipmentHash1),
  );
  await confirm(
    "3. Manufacturer records passing cold-chain log",
    registry.connect(manufacturer).logColdChain(batchId, "ipfs://demo-temperature-log-1", firstLogHash, true),
  );
  await confirm("4. Distributor confirms receipt", registry.connect(distributor).confirmReceipt(batchId));

  await confirm(
    "5. Distributor starts transfer to pharmacy",
    registry.connect(distributor).transferCustody(batchId, pharmacy.address, "ipfs://demo-shipment-2", shipmentHash2),
  );
  await confirm(
    "6. Distributor records passing cold-chain log",
    registry.connect(distributor).logColdChain(batchId, "ipfs://demo-temperature-log-2", secondLogHash, true),
  );
  await confirm("7. Pharmacy confirms receipt", registry.connect(pharmacy).confirmReceipt(batchId));
  await confirm(
    "8. Regulator verifies batch",
    registry.connect(regulator).verifyBatch(batchId, false, ethers.keccak256(ethers.toUtf8Bytes("demo verification"))),
  );
  await confirm("9. Pharmacy marks batch dispensed", registry.connect(pharmacy).markDispensed(batchId));

  const batch = await registry.getBatch(batchId);
  const history = await registry.getCustodyHistory(batchId);
  console.log("\nFinal on-chain state");
  console.log(`State: ${STATE_NAMES[Number(batch.state)]}`);
  console.log(`Current custodian: ${batch.currentCustodian}`);
  console.log(`Cold-chain passed: ${batch.coldChainPassed}`);
  console.log(`Custody records: ${history.length}`);
  console.log("Events emitted: BatchRegistered, CustodyTransferred, BatchReceived, ColdChainLogged, BatchVerified, BatchDispensed");
  console.log("\nNote: IPFS CIDs in this demo are placeholders; no files are uploaded.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
