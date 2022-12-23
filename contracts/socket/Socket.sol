// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

// import "../interfaces/IVerifier.sol";
import "../interfaces/IDeaccumulator.sol";
import "../interfaces/IPlug.sol";

import "./SocketLocal.sol";

interface IVerifier {
    /**
     * @notice verifies if the packet satisfies needed checks before execution
     * @param root_ root_
     */
    function verifyPacket(
        bytes32 root_,
        bytes32 integrationType_
    ) external view returns (bool);
}

contract Socket is SocketLocal {
    enum PacketStatus {
        NOT_PROPOSED,
        PROPOSED
    }

    enum MessageStatus {
        NOT_EXECUTED,
        SUCCESS,
        FAILED
    }

    error InvalidProof();
    error InvalidRetry();
    error VerificationFailed();
    error MessageAlreadyExecuted();
    error ExecutorNotFound();
    error AlreadyAttested();
    error RootNotFound();

    // keccak256("EXECUTOR")
    bytes32 private constant EXECUTOR_ROLE =
        0x9cf85f95575c3af1e116e3d37fd41e7f36a8a373623f51ffaaa87fdd032fa767;

    // msgId => executorAddress
    mapping(uint256 => address) public executor;
    // msgId => message status
    mapping(uint256 => MessageStatus) public messageStatus;
    // accumAddr|chainSlug|packetId
    mapping(bytes32 => bool) public remoteRoots;

    /**
     * @notice emits the packet details when proposed at remote
     * @param attester address of attester
     * @param root packet root
     */
    event PacketAttested(address indexed attester, bytes32 root);

    /**
     * @notice emits the root when it is removed by owner
     * @param oldRoot old root
     */
    event PacketRootRemoved(bytes32 oldRoot);

    constructor(
        uint32 chainSlug_,
        address hasher_,
        address signatureVerifier_,
        address transmitManager_,
        address vault_
    ) {
        hasher = IHasher(hasher_);
        signatureVerifier = ISignatureVerifier(signatureVerifier_);
        transmitManager = ITransmitManager(transmitManager_);
        vault = IVault(vault_);

        chainSlug = chainSlug_;
    }

    // TODO: taking sibling chain input is prone to bug as we saw in previous version
    function propose(
        uint256 siblingChainSlug_,
        bytes32 root_,
        bytes calldata signature_
    ) external {
        if (remoteRoots[root_]) revert AlreadyAttested();
        if (
            !transmitManager.checkTransmitter(
                chainSlug,
                siblingChainSlug_,
                root_,
                signature_
            )
        ) revert InvalidAttester();

        remoteRoots[root_] = true;
        emit PacketAttested(msg.sender, root_);
    }

    /**
     * @notice executes a message
     * @param msgGasLimit gas limit needed to execute the inbound at remote
     * @param msgId message id packed with local plug, local chainSlug, remote ChainSlug and nonce
     * @param localPlug remote plug address
     * @param payload the data which is needed by plug at inbound call on remote
     * @param verifyParams_ the details needed for message verification
     */
    function execute(
        uint256 msgGasLimit,
        uint256 msgId,
        address localPlug,
        bytes calldata payload,
        ISocket.VerificationParams calldata verifyParams_
    ) external override nonReentrant {
        if (!_hasRole(EXECUTOR_ROLE, msg.sender)) revert ExecutorNotFound();
        if (!remoteRoots[verifyParams_.root]) revert RootNotFound();
        if (executor[msgId] != address(0)) revert MessageAlreadyExecuted();

        // todo: to decide if this should be just a bool (was added for fees here)
        executor[msgId] = msg.sender;

        PlugConfig memory plugConfig = plugConfigs[localPlug][
            verifyParams_.remoteChainSlug
        ];

        bytes32 packedMessage = hasher.packMessage(
            verifyParams_.remoteChainSlug,
            plugConfig.remotePlug,
            chainSlug,
            localPlug,
            msgId,
            msgGasLimit,
            payload
        );

        _verify(packedMessage, plugConfig, verifyParams_);
        _execute(
            localPlug,
            verifyParams_.remoteChainSlug,
            msgGasLimit,
            msgId,
            payload
        );
    }

    function _verify(
        bytes32 packedMessage,
        PlugConfig memory plugConfig,
        ISocket.VerificationParams calldata verifyParams_
    ) internal view {
        // TODO: do we need inboundIntegrationType at verifier with switchboards?
        bool isVerified = IVerifier(plugConfig.verifier).verifyPacket(
            verifyParams_.root,
            plugConfig.inboundIntegrationType
        );

        if (!isVerified) revert VerificationFailed();
        if (
            !IDeaccumulator(plugConfig.deaccum).verifyMessageInclusion(
                verifyParams_.root,
                packedMessage,
                verifyParams_.deaccumProof
            )
        ) revert InvalidProof();
    }

    function _execute(
        address localPlug,
        uint256 remoteChainSlug,
        uint256 msgGasLimit,
        uint256 msgId,
        bytes calldata payload
    ) internal {
        try
            IPlug(localPlug).inbound{gas: msgGasLimit}(remoteChainSlug, payload)
        {
            messageStatus[msgId] = MessageStatus.SUCCESS;
            emit ExecutionSuccess(msgId);
        } catch Error(string memory reason) {
            // catch failing revert() and require()
            messageStatus[msgId] = MessageStatus.FAILED;
            emit ExecutionFailed(msgId, reason);
        } catch (bytes memory reason) {
            // catch failing assert()
            messageStatus[msgId] = MessageStatus.FAILED;
            emit ExecutionFailedBytes(msgId, reason);
        }
    }

    /**
     * @notice discards root
     * @param oldRoot_ existing root
     */
    function removePacketRoot(bytes32 oldRoot_) external onlyOwner {
        remoteRoots[oldRoot_] = false;
        emit PacketRootRemoved(oldRoot_);
    }

    /**
     * @notice adds an executor
     * @param executor_ executor address
     */
    function grantExecutorRole(address executor_) external onlyOwner {
        _grantRole(EXECUTOR_ROLE, executor_);
    }

    /**
     * @notice removes an executor from `remoteChainSlug_` chain list
     * @param executor_ executor address
     */
    function revokeExecutorRole(address executor_) external onlyOwner {
        _revokeRole(EXECUTOR_ROLE, executor_);
    }

    function getPacketStatus(
        bytes32 root_
    ) external view returns (PacketStatus status) {
        return
            !remoteRoots[root_]
                ? PacketStatus.NOT_PROPOSED
                : PacketStatus.PROPOSED;
    }
}
