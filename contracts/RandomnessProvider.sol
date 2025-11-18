// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RandomnessProvider
 * @notice Chainlink VRF integration for provably fair randomness
 * @dev Provides random numbers to VendingMachine and RaffleManager contracts
 */
contract RandomnessProvider is VRFConsumerBaseV2, Ownable {
    
    // Chainlink VRF variables
    VRFCoordinatorV2Interface public immutable COORDINATOR;
    uint64 public subscriptionId;
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 500000;
    uint16 public requestConfirmations = 3;
    
    // State variables
    mapping(uint256 => address) public requestToContract; // requestId => requesting contract
    mapping(address => bool) public authorizedContracts;
    
    // Events
    event RandomnessRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint32 numWords
    );
    event RandomnessFulfilled(
        uint256 indexed requestId,
        uint256[] randomWords
    );
    event ContractAuthorized(address indexed contractAddress);
    event ContractRevoked(address indexed contractAddress);
    event ConfigUpdated(
        uint64 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations
    );

    // Errors
    error Unauthorized();
    error InvalidAddress();
    error InvalidConfig();

    /**
     * @notice Constructor
     * @param _vrfCoordinator Chainlink VRF Coordinator address
     * @param _subscriptionId Chainlink VRF subscription ID
     * @param _keyHash Chainlink VRF key hash (gas lane)
     */
    constructor(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        if (_vrfCoordinator == address(0)) revert InvalidAddress();
        if (_keyHash == bytes32(0)) revert InvalidConfig();

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
    }

    /**
     * @notice Request random words from Chainlink VRF
     * @param numWords Number of random words to request
     * @return requestId The request ID
     */
    function requestRandomWords(uint32 numWords) 
        external 
        returns (uint256 requestId) 
    {
        if (!authorizedContracts[msg.sender]) revert Unauthorized();
        if (numWords == 0 || numWords > 500) revert InvalidConfig();

        // Request randomness from VRF Coordinator
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        // Store requesting contract
        requestToContract[requestId] = msg.sender;

        emit RandomnessRequested(requestId, msg.sender, numWords);

        return requestId;
    }

    /**
     * @notice Callback function used by VRF Coordinator
     * @param requestId The request ID
     * @param randomWords Array of random numbers
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        address requester = requestToContract[requestId];
        
        if (requester == address(0)) {
            return; // No requester found, shouldn't happen
        }

        emit RandomnessFulfilled(requestId, randomWords);

        // Forward randomness to requesting contract
        (bool success, ) = requester.call(
            abi.encodeWithSignature(
                "fulfillRandomness(uint256,uint256[])",
                requestId,
                randomWords
            )
        );

        // Note: We don't revert if call fails to prevent stuck requests
        // The requesting contract should handle failures gracefully
        if (!success) {
            // Could emit an event here for monitoring
        }
    }

    /**
     * @notice Get request status
     * @param requestId The request ID
     * @return requester Address that made the request
     */
    function getRequestStatus(uint256 requestId) 
        external 
        view 
        returns (address requester) 
    {
        return requestToContract[requestId];
    }

    // Admin functions

    /**
     * @notice Authorize a contract to request randomness
     * @param contractAddress Contract address to authorize
     */
    function authorizeContract(address contractAddress) external onlyOwner {
        if (contractAddress == address(0)) revert InvalidAddress();
        
        authorizedContracts[contractAddress] = true;
        emit ContractAuthorized(contractAddress);
    }

    /**
     * @notice Revoke contract authorization
     * @param contractAddress Contract address to revoke
     */
    function revokeContract(address contractAddress) external onlyOwner {
        authorizedContracts[contractAddress] = false;
        emit ContractRevoked(contractAddress);
    }

    /**
     * @notice Update VRF configuration
     * @param _subscriptionId New subscription ID
     * @param _keyHash New key hash
     * @param _callbackGasLimit New callback gas limit
     * @param _requestConfirmations New request confirmations
     */
    function updateConfig(
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) external onlyOwner {
        if (_keyHash == bytes32(0)) revert InvalidConfig();
        if (_callbackGasLimit == 0) revert InvalidConfig();
        if (_requestConfirmations == 0) revert InvalidConfig();

        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;

        emit ConfigUpdated(
            _subscriptionId,
            _keyHash,
            _callbackGasLimit,
            _requestConfirmations
        );
    }

    /**
     * @notice Check if contract is authorized
     * @param contractAddress Contract address to check
     * @return Whether contract is authorized
     */
    function isAuthorized(address contractAddress) 
        external 
        view 
        returns (bool) 
    {
        return authorizedContracts[contractAddress];
    }
}
