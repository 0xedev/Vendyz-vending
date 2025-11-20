// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title TokenTreasury
 * @notice Holds token inventory and funds newly generated wallets
 * @dev Backend service calls fundWallet to distribute tokens to users
 */
contract TokenTreasury is Ownable, ReentrancyGuard, Pausable {
    
    // Authorized backend addresses that can fund wallets
    mapping(address => bool) public authorizedBackends;
    
    // Track total funded per token
    mapping(address => uint256) public totalFunded;
    
    // Track funding per wallet
    mapping(address => mapping(address => uint256)) public walletFunding; // wallet => token => amount

    // Events
    event BackendAuthorized(address indexed backend);
    event BackendRevoked(address indexed backend);
    event WalletFunded(
        address indexed wallet,
        address indexed requester,
        address[] tokens,
        uint256[] amounts,
        uint256 requestId
    );
    event TokensDeposited(address indexed token, uint256 amount, address indexed depositor);
    event TokensWithdrawn(address indexed token, uint256 amount, address indexed recipient);
    event EmergencyWithdrawal(address indexed token, uint256 amount);

    // Errors
    error Unauthorized();
    error InvalidAddress();
    error InvalidArrayLength();
    error InsufficientBalance();
    error TransferFailed();

    /**
     * @notice Constructor
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @notice Fund a wallet with multiple tokens
     * @param wallet Address of wallet to fund
     * @param tokens Array of token addresses
     * @param amounts Array of token amounts (must match tokens length)
     * @param requestId VRF request ID for tracking
     */
    function fundWallet(
        address wallet,
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256 requestId
    ) external nonReentrant whenNotPaused {
        if (!authorizedBackends[msg.sender]) revert Unauthorized();
        if (wallet == address(0)) revert InvalidAddress();
        if (tokens.length != amounts.length) revert InvalidArrayLength();
        if (tokens.length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert InvalidAddress();
            if (amounts[i] == 0) continue; // Skip zero amounts

            IERC20 token = IERC20(tokens[i]);
            
            // Check balance
            uint256 balance = token.balanceOf(address(this));
            if (balance < amounts[i]) revert InsufficientBalance();

            // Transfer token to wallet
            bool success = token.transfer(wallet, amounts[i]);
            if (!success) revert TransferFailed();

            // Track funding
            totalFunded[tokens[i]] += amounts[i];
            walletFunding[wallet][tokens[i]] += amounts[i];
        }

        emit WalletFunded(wallet, msg.sender, tokens, amounts, requestId);
    }

    /**
     * @notice Deposit tokens into treasury
     * @param token Token address
     * @param amount Amount to deposit
     */
    function depositTokens(address token, uint256 amount) external nonReentrant {
        if (token == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidArrayLength();

        IERC20 tokenContract = IERC20(token);
        bool success = tokenContract.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();

        emit TokensDeposited(token, amount, msg.sender);
    }

    /**
     * @notice Withdraw tokens from treasury (owner only)
     * @param token Token address
     * @param amount Amount to withdraw
     * @param recipient Recipient address
     */
    function withdrawTokens(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner nonReentrant {
        if (token == address(0) || recipient == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidArrayLength();

        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        bool success = tokenContract.transfer(recipient, amount);
        if (!success) revert TransferFailed();

        emit TokensWithdrawn(token, amount, recipient);
    }

    /**
     * @notice Batch deposit multiple tokens
     * @param tokens Array of token addresses
     * @param amounts Array of amounts
     */
    function batchDepositTokens(
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external nonReentrant {
        if (tokens.length != amounts.length) revert InvalidArrayLength();
        if (tokens.length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert InvalidAddress();
            if (amounts[i] == 0) continue;

            IERC20 tokenContract = IERC20(tokens[i]);
            bool success = tokenContract.transferFrom(msg.sender, address(this), amounts[i]);
            if (!success) revert TransferFailed();

            emit TokensDeposited(tokens[i], amounts[i], msg.sender);
        }
    }

    /**
     * @notice Get token balance in treasury
     * @param token Token address
     * @return Balance of token
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Get multiple token balances
     * @param tokens Array of token addresses
     * @return Array of balances
     */
    function getBatchTokenBalances(address[] calldata tokens) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256[] memory balances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = IERC20(tokens[i]).balanceOf(address(this));
        }
        return balances;
    }

    /**
     * @notice Get total funded amount for a token
     * @param token Token address
     * @return Total amount funded
     */
    function getTotalFunded(address token) external view returns (uint256) {
        return totalFunded[token];
    }

    /**
     * @notice Get funding details for a wallet
     * @param wallet Wallet address
     * @param token Token address
     * @return Amount funded to wallet
     */
    function getWalletFunding(address wallet, address token) 
        external 
        view 
        returns (uint256) 
    {
        return walletFunding[wallet][token];
    }

    // Admin functions

    /**
     * @notice Authorize backend address
     * @param backend Backend address
     */
    function authorizeBackend(address backend) external onlyOwner {
        if (backend == address(0)) revert InvalidAddress();
        authorizedBackends[backend] = true;
        emit BackendAuthorized(backend);
    }

    /**
     * @notice Revoke backend authorization
     * @param backend Backend address
     */
    function revokeBackend(address backend) external onlyOwner {
        authorizedBackends[backend] = false;
        emit BackendRevoked(backend);
    }

    /**
     * @notice Check if address is authorized backend
     * @param backend Address to check
     * @return Whether address is authorized
     */
    function isAuthorizedBackend(address backend) external view returns (bool) {
        return authorizedBackends[backend];
    }

    /**
     * @notice Emergency withdraw all tokens (owner only)
     * @param token Token address
     */
    function emergencyWithdraw(address token) external onlyOwner {
        if (token == address(0)) revert InvalidAddress();
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        
        if (balance > 0) {
            bool success = tokenContract.transfer(owner(), balance);
            if (!success) revert TransferFailed();
            
            emit EmergencyWithdrawal(token, balance);
        }
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Receive ETH (not used, but allows accidental ETH sends)
     */
    receive() external payable {
        // Accept ETH but don't do anything with it
    }

    /**
     * @notice Withdraw ETH if accidentally sent
     */
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
        }
    }
}
