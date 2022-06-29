// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.10;

abstract contract IAccumulator {
    bytes32 SOCKET_ROLE = keccak256("SOCKET_ROLE");
    bytes32 NOTARY_ROLE = keccak256("NOTARY_ROLE");

    event SocketSet(address indexed socket);
    event NotarySet(address indexed notary);
    event PacketAdded(bytes32 packetHash, bytes32 newRootHash);
    event BatchComplete(bytes32 rootHash, uint256 batchId);

    // caller only Socket
    function addPacket(bytes32 packetHash) external virtual;

    function getNextBatch() external view virtual returns (bytes32, uint256);

    function getRootById(uint256 id) external view virtual returns (bytes32);

    // caller only Notary
    function incrementBatch() external virtual returns (bytes32);
}
