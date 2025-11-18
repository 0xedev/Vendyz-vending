// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RandomnessProvider
 * @notice Chainlink VRF 2.5 Direct Funding integration for provably fair randomness
 * @dev Provides random numbers to VendingMachine and RaffleManager contracts
 * Uses direct funding method - pays per request in native token
 */
contract RandomnessProvider is VRFConsumerBaseV2Plus, Ownable {
    
    // Chainlink VRF variables
    bytes32 public keyHash;
    uint32 public callbackGasLimit = 500000;
    uint16 public requestConfirmations = 3;
    uint32 public numWords = 1;
    
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
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations
    );
    event NativeFundsDeposited(address indexed sender, uint256 amount);
    event NativeFundsWithdrawn(address indexed owner, uint256 amount);

    // Errors
    error Unauthorized();
    error InvalidAddress();
    error InvalidConfig();
    error InsufficientBalance();

    /**
     * @notice Constructor
     * @param _vrfCoordinator Chainlink VRF Coordinator address
     * @param _keyHash Chainlink VRF key hash (gas lane)
     */
    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        if (_vrfCoordinator == address(0)) revert InvalidAddress();
        if (_keyHash == bytes32(0)) revert InvalidConfig();

        keyHash = _keyHash;
    }

    /**
     * @notice Request random words from Chainlink VRF using direct funding
     * @param _numWords Number of random words to request
     * @return requestId The request ID
     */
    function requestRandomWords(uint32 _numWords) 
        external 
        returns (uint256 requestId) 
    {
        if (!authorizedContracts[msg.sender]) revert Unauthorized();
        if (_numWords == 0 || _numWords > 500) revert InvalidConfig();

        // Request randomness from VRF Coordinator with direct funding (native payment)
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: 0, // 0 for direct funding
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: _numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: true // Pay in native token (ETH)
                    })
                )
            })
        );

        // Store requesting contract
        requestToContract[requestId] = msg.sender;

        emit RandomnessRequested(requestId, msg.sender, _numWords);

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
     * @param _keyHash New key hash
     * @param _callbackGasLimit New callback gas limit
     * @param _requestConfirmations New request confirmations
     */
    function updateConfig(
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) external onlyOwner {
        if (_keyHash == bytes32(0)) revert InvalidConfig();
        if (_callbackGasLimit == 0) revert InvalidConfig();
        if (_requestConfirmations == 0) revert InvalidConfig();

        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;

        emit ConfigUpdated(
            _keyHash,
            _callbackGasLimit,
            _requestConfirmations
        );
    }

    /**
     * @notice Deposit native tokens (ETH) to pay for VRF requests
     * @dev Contract must have ETH balance to pay for randomness requests
     */
    function depositNativeFunds() external payable {
        emit NativeFundsDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw native tokens from contract
     * @param amount Amount to withdraw
     */
    function withdrawNativeFunds(uint256 amount) external onlyOwner {
        if (address(this).balance < amount) revert InsufficientBalance();
        
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit NativeFundsWithdrawn(owner(), amount);
    }

    /**
     * @notice Get contract's native token balance
     * @return Balance in wei
     */
    function getNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Receive function to accept native token deposits
     */
    receive() external payable {
        emit NativeFundsDeposited(msg.sender, msg.value);
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
