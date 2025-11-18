// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockRandomnessProvider {
    uint256 private nextRequestId = 1;

    mapping(uint256 => address) public requestToContract;

    event RandomnessRequested(uint256 indexed requestId, address indexed requester);

    function requestRandomWords(uint32 numWords) external returns (uint256 requestId) {
        requestId = nextRequestId++;
        requestToContract[requestId] = msg.sender;
        emit RandomnessRequested(requestId, msg.sender);
        return requestId;
    }

    function fulfillRequest(
        address contractAddress,
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        (bool success, ) = contractAddress.call(
            abi.encodeWithSignature(
                "fulfillRandomness(uint256,uint256[])",
                requestId,
                randomWords
            )
        );
        require(success, "Fulfillment failed");
    }
}
