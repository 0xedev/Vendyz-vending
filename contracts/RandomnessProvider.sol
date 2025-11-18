// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

/**
 * @title RandomnessProvider
 * @notice Chainlink VRF 2.5 Direct Funding integration for provably fair randomness
 * @dev Provides random numbers to VendingMachine and RaffleManager contracts
 * Uses direct funding method - pays per request in native token
 * Note: Inherits ownership from ConfirmedOwner
 */
contract RandomnessProvider is VRFV2PlusWrapperConsumerBase, ConfirmedOwner  {
    
    // Chainlink VRF variables
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
     * @param _wrapperAddress Chainlink VRF Wrapper address
     */
    constructor(
        address _wrapperAddress
    ) 
        ConfirmedOwner(msg.sender)
        VRFV2PlusWrapperConsumerBase(_wrapperAddress) 
    {
        if (_wrapperAddress == address(0)) revert InvalidAddress();
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

        // Build extraArgs with native payment enabled
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({
                nativePayment: true // Pay in native token (ETH)
            })
        );

        // Request randomness using wrapper (direct funding with native payment)
        (requestId, ) = requestRandomnessPayInNative(
            callbackGasLimit,
            requestConfirmations,
            _numWords,
            extraArgs
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
        uint256[] calldata randomWords
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
     * @param _callbackGasLimit New callback gas limit
     * @param _requestConfirmations New request confirmations
     */
    function updateConfig(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) external onlyOwner {
        if (_callbackGasLimit == 0) revert InvalidConfig();
        if (_requestConfirmations == 0) revert InvalidConfig();

        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;

        emit ConfigUpdated(
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
