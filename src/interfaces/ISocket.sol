// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./IVault.sol";

interface ISocket {
    // to handle stack too deep
    struct VerificationParams {
        uint256 remoteChainId;
        address remoteAccum;
        uint256 packetId;
        bytes deaccumProof;
    }

    /**
     * @notice emits the message details when a new message arrives at outbound
     * @param srcChainId src chain id
     * @param srcPlug src plug address
     * @param dstChainId dest chain id
     * @param dstPlug dest plug address
     * @param msgId message id packed with destChainId and nonce
     * @param msgGasLimit gas limit needed to execute the inbound at destination
     * @param payload the data which will be used by inbound at destination
     */
    event MessageTransmitted(
        uint256 srcChainId,
        address srcPlug,
        uint256 dstChainId,
        address dstPlug,
        uint256 msgId,
        uint256 msgGasLimit,
        bytes payload
    );

    /**
     * @notice emits the status of message after inbound call
     * @param msgId msg id which is executed
     */
    event ExecutionSuccess(uint256 msgId);

    /**
     * @notice emits the status of message after inbound call
     * @param msgId msg id which is executed
     * @param success true if message not reverted else false
     * @param result if message reverts, returns the revert message
     */
    event ExecutionFailed(uint256 msgId, bool success, string result);

    /**
     * @notice emits the error message in bytes after inbound call
     * @param msgId msg id which is executed
     * @param success true if message not reverted else false
     * @param result if message reverts, returns the revert message in bytes
     */
    event ExecutionFailedBytes(uint256 msgId, bool success, bytes result);

    error NotAttested();

    error InvalidRemotePlug();

    error InvalidProof();

    error VerificationFailed();

    error MessageAlreadyExecuted();

    error InsufficientGasLimit();

    error ExecutorNotFound();

    function vault() external view returns (IVault);

    /**
     * @notice registers a message
     * @dev Packs the message and includes it in a packet with accumulator
     * @param remoteChainId_ the destination chain id
     * @param msgGasLimit_ the gas limit needed to execute the payload on destination
     * @param payload_ the data which is needed by plug at inbound call on destination
     */
    function outbound(
        uint256 remoteChainId_,
        uint256 msgGasLimit_,
        bytes calldata payload_
    ) external payable;

    /**
     * @notice executes a message
     * @param msgGasLimit gas limit needed to execute the inbound at destination
     * @param msgId message id packed with destChainId and nonce
     * @param localPlug dest plug address
     * @param payload the data which is needed by plug at inbound call on destination
     * @param verifyParams_ the details needed for message verification
     */
    function execute(
        uint256 msgGasLimit,
        uint256 msgId,
        address localPlug,
        bytes calldata payload,
        ISocket.VerificationParams calldata verifyParams_
    ) external;

    // TODO: add confs and blocking/non-blocking
    struct InboundConfig {
        address remotePlug;
        address deaccum;
        address verifier;
    }

    struct OutboundConfig {
        address accum;
        address remotePlug;
    }

    /**
     * @notice sets the config specific to the plug
     * @param remoteChainId_ the destination chain id
     * @param remotePlug_ address of plug present at destination chain to call inbound
     * @param deaccum_ address of deaccum which is used to verify proof
     * @param verifier_ address of verifier responsible for final packet validity checks
     */
    function setInboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address deaccum_,
        address verifier_
    ) external;

    /**
     * @notice sets the config specific to the plug
     * @param remoteChainId_ the destination chain id
     * @param remotePlug_ address of plug present at destination chain to call inbound
     * @param accum_ address of accumulator which is used for collecting the messages and form packets
     */
    function setOutboundConfig(
        uint256 remoteChainId_,
        address remotePlug_,
        address accum_
    ) external;
}
