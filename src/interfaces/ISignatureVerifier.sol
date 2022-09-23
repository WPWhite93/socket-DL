// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface ISignatureVerifier {
    /**
     * @notice returns the address of signer recovered from input signature
     * @param remoteChainId_ destination chain id
     * @param accumAddress_ accumulator address
     * @param packetId_ packet id
     * @param root_ root hash of merkle tree
     * @param signature_ signature
     */
    function recoverSigner(
        uint256 remoteChainId_,
        address accumAddress_,
        uint256 packetId_,
        bytes32 root_,
        bytes calldata signature_
    ) external returns (address);
}
