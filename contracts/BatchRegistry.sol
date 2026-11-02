// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title PharmaChain Batch Registry
/// @notice Prototype registry for drug batches and cold-chain records.
/// @dev Certificates and sensor logs stay off-chain; the contract stores their CIDs and hashes.
contract BatchRegistry is AccessControl {
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant PHARMACY_ROLE = keccak256("PHARMACY_ROLE");
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");

    enum State {
        Manufactured,
        Shipped,
        Received,
        Verified,
        Dispensed,
        Recalled
    }

    struct CustodyRecord {
        address from;
        address to;
        uint64 timestamp;
        string evidenceCID;
        bytes32 evidenceHash;
    }

    struct Batch {
        address manufacturer;
        address currentCustodian;
        address pendingCustodian;
        string metadataCID;
        bytes32 metadataHash;
        string latestColdChainCID;
        bytes32 latestColdChainHash;
        State state;
        bool coldChainPassed;
        bool currentLegLogRecorded;
        bool coldChainExceptionApproved;
        bool exists;
    }

    mapping(bytes32 => Batch) private batches;
    mapping(bytes32 => CustodyRecord[]) private custodyHistory;

    event BatchRegistered(bytes32 indexed batchId, address indexed manufacturer, string metadataCID, bytes32 metadataHash);
    event CustodyTransferred(bytes32 indexed batchId, address indexed from, address indexed to, string evidenceCID, bytes32 evidenceHash);
    event BatchReceived(bytes32 indexed batchId, address indexed custodian);
    event ColdChainLogged(bytes32 indexed batchId, address indexed custodian, string logCID, bytes32 logHash, bool passed);
    event BatchVerified(bytes32 indexed batchId, address indexed regulator, bool coldChainPassed, bool exceptionApproved, bytes32 verificationHash);
    event BatchDispensed(bytes32 indexed batchId, address indexed pharmacy);
    event BatchRecalled(bytes32 indexed batchId, address indexed regulator, bytes32 reasonHash);

    modifier batchExists(bytes32 batchId) {
        require(batches[batchId].exists, "Unknown batch");
        _;
    }

    constructor(address consortiumAdmin) {
        require(consortiumAdmin != address(0), "Zero admin address");
        _grantRole(DEFAULT_ADMIN_ROLE, consortiumAdmin);
    }

    /// @notice Adds a batch with its manufacturer and metadata record.
    /// @dev The batch ID should be a unique identifier hash.
    function registerBatch(
        bytes32 batchId,
        string calldata metadataCID,
        bytes32 metadataHash
    ) external onlyRole(MANUFACTURER_ROLE) {
        require(!batches[batchId].exists, "Batch already registered");
        require(bytes(metadataCID).length > 0, "Metadata CID required");

        batches[batchId] = Batch({
            manufacturer: msg.sender,
            currentCustodian: msg.sender,
            pendingCustodian: address(0),
            metadataCID: metadataCID,
            metadataHash: metadataHash,
            latestColdChainCID: "",
            latestColdChainHash: bytes32(0),
            state: State.Manufactured,
            coldChainPassed: true,
            currentLegLogRecorded: false,
            coldChainExceptionApproved: false,
            exists: true
        });
        emit BatchRegistered(batchId, msg.sender, metadataCID, metadataHash);
    }

    /// @notice Starts a handoff to an authorized distributor or pharmacy.
    /// @dev The recipient confirms delivery with confirmReceipt.
    function transferCustody(
        bytes32 batchId,
        address recipient,
        string calldata evidenceCID,
        bytes32 evidenceHash
    ) external batchExists(batchId) {
        Batch storage batch = batches[batchId];
        require(msg.sender == batch.currentCustodian, "Caller is not current custodian");
        require(batch.state == State.Manufactured || batch.state == State.Received, "Invalid transfer state");
        require(recipient != address(0) && recipient != msg.sender, "Invalid recipient");
        require(
            hasRole(DISTRIBUTOR_ROLE, recipient) || hasRole(PHARMACY_ROLE, recipient),
            "Recipient is not a distributor or pharmacy"
        );
        require(bytes(evidenceCID).length > 0, "Shipment evidence CID required");

        batch.pendingCustodian = recipient;
        batch.currentLegLogRecorded = false;
        batch.state = State.Shipped;
        custodyHistory[batchId].push(CustodyRecord({
            from: msg.sender,
            to: recipient,
            timestamp: uint64(block.timestamp),
            evidenceCID: evidenceCID,
            evidenceHash: evidenceHash
        }));
        emit CustodyTransferred(batchId, msg.sender, recipient, evidenceCID, evidenceHash);
    }

    /// @notice Confirms delivery and makes the recipient the new custodian.
    function confirmReceipt(bytes32 batchId) external batchExists(batchId) {
        Batch storage batch = batches[batchId];
        require(batch.state == State.Shipped, "Batch is not shipped");
        require(batch.currentLegLogRecorded, "Cold-chain log required");
        require(msg.sender == batch.pendingCustodian, "Caller is not pending custodian");

        batch.currentCustodian = msg.sender;
        batch.pendingCustodian = address(0);
        batch.state = State.Received;
        emit BatchReceived(batchId, msg.sender);
    }

    /// @notice Records the CID, hash, and result for a simulated temperature log.
    /// @dev A failed cold-chain check needs regulator approval before the batch can be dispensed.
    function logColdChain(
        bytes32 batchId,
        string calldata logCID,
        bytes32 logHash,
        bool passed
    ) external batchExists(batchId) {
        Batch storage batch = batches[batchId];
        require(msg.sender == batch.currentCustodian, "Caller is not current custodian");
        require(batch.state == State.Shipped, "Batch is not shipped");
        require(bytes(logCID).length > 0, "Log CID required");

        batch.latestColdChainCID = logCID;
        batch.latestColdChainHash = logHash;
        batch.currentLegLogRecorded = true;
        if (!passed) {
            batch.coldChainPassed = false;
            batch.coldChainExceptionApproved = false;
        }
        emit ColdChainLogged(batchId, msg.sender, logCID, logHash, passed);
    }

    /// @notice Lets a regulator verify a batch after it reaches a pharmacy.
    /// @dev A failed cold-chain check requires an explicit exception.
    function verifyBatch(bytes32 batchId, bool approveColdChainException, bytes32 verificationHash)
        external
        onlyRole(REGULATOR_ROLE)
        batchExists(batchId)
    {
        Batch storage batch = batches[batchId];
        require(batch.state == State.Received, "Batch must be received before verification");
        require(hasRole(PHARMACY_ROLE, batch.currentCustodian), "Batch must be at a pharmacy");
        require(batch.coldChainPassed || approveColdChainException, "Cold-chain failure needs regulator exception");

        batch.coldChainExceptionApproved = !batch.coldChainPassed && approveColdChainException;
        batch.state = State.Verified;
        emit BatchVerified(batchId, msg.sender, batch.coldChainPassed, batch.coldChainExceptionApproved, verificationHash);
    }

    /// @notice Lets the current pharmacy mark a verified batch as dispensed.
    function markDispensed(bytes32 batchId) external batchExists(batchId) {
        Batch storage batch = batches[batchId];
        require(hasRole(PHARMACY_ROLE, msg.sender), "Caller is not a pharmacy");
        require(msg.sender == batch.currentCustodian, "Caller is not current custodian");
        require(batch.state == State.Verified, "Batch is not verified");
        require(batch.coldChainPassed || batch.coldChainExceptionApproved, "Cold-chain issue not approved");

        batch.state = State.Dispensed;
        emit BatchDispensed(batchId, msg.sender);
    }

    /// @notice Lets a regulator recall a batch at any point in its lifecycle.
    function recallBatch(bytes32 batchId, bytes32 reasonHash)
        external
        onlyRole(REGULATOR_ROLE)
        batchExists(batchId)
    {
        Batch storage batch = batches[batchId];
        require(batch.state != State.Recalled, "Batch already recalled");
        batch.state = State.Recalled;
        batch.pendingCustodian = address(0);
        emit BatchRecalled(batchId, msg.sender, reasonHash);
    }

    /// @notice Returns current batch details for read-only lookups.
    function getBatch(bytes32 batchId) external view batchExists(batchId) returns (Batch memory) {
        return batches[batchId];
    }

    /// @notice Returns the recorded custody history for a batch.
    function getCustodyHistory(bytes32 batchId)
        external
        view
        batchExists(batchId)
        returns (CustodyRecord[] memory)
    {
        return custodyHistory[batchId];
    }
}
