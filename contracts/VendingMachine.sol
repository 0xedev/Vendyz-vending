// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IRandomnessProvider.sol";

/**
 * @title VendingMachine
 * @notice Main contract for the anonymous wallet vending machine
 * @dev Users pay USDC to receive pre-funded anonymous wallets
 */
contract VendingMachine is Ownable, ReentrancyGuard, Pausable {
    
    // Structs
    struct Tier {
        uint256 price;          // Price in USDC (6 decimals)
        uint256 minValue;       // Minimum wallet value in USDC
        uint256 maxValue;       // Maximum wallet value in USDC
        bool active;            // Whether tier is available
    }

    struct Purchase {
        address buyer;
        uint8 tier;
        uint256 timestamp;
        uint256 pricePaid;
        bool fulfilled;
        uint256[] randomWords;
    }

    // State variables
    IERC20 public immutable usdc;
    IRandomnessProvider public randomnessProvider;
    
    mapping(uint8 => Tier) public tiers;
    mapping(uint256 => Purchase) public purchases; // requestId => Purchase
    mapping(address => uint256) public userPurchaseCount;
    mapping(uint256 => uint256) public vrfRequestTimestamp; // requestId => timestamp
    
    uint256[] public allPurchaseIds; // All request IDs for history
    mapping(address => uint256[]) public userPurchaseIds; // user => request IDs
    
    address public treasury;
    uint256 public totalRevenue;
    uint256 public totalPurchases;
    
    uint8 public constant MAX_TIERS = 4;
    uint256 public constant HOUSE_EDGE_PERCENT = 10; // 10% house edge
    uint256 public constant VRF_CALLBACK_TIMEOUT = 1 hours; // Time before emergency intervention

    // Events
    event PurchaseInitiated(
        address indexed buyer,
        uint8 indexed tier,
        uint256 requestId,
        uint256 price
    );
    
    event WalletReady(
        uint256 indexed requestId,
        address indexed buyer,
        uint8 tier,
        uint256 estimatedValue
    );
    
    event TierUpdated(
        uint8 indexed tier,
        uint256 price,
        uint256 minValue,
        uint256 maxValue,
        bool active
    );
    
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event RevenueWithdrawn(address indexed to, uint256 amount);
    event EmergencyFulfillment(uint256 indexed requestId, uint256 walletValue);
    event PurchaseRefunded(uint256 indexed requestId, address indexed buyer, uint256 amount);

    // Errors
    error InvalidTier();
    error VRFTimeoutNotReached();
    error TierNotActive();
    error InvalidPayment();
    error PurchaseNotFound();
    error AlreadyFulfilled();
    error InvalidAddress();
    error InvalidTierParameters();

    /**
     * @notice Constructor
     * @param _usdc USDC token address
     * @param _randomnessProvider Chainlink VRF provider
     * @param _treasury Treasury address for revenue
     */
    constructor(
        address _usdc,
        address _randomnessProvider,
        address _treasury
    ) Ownable(msg.sender) {
        if (_usdc == address(0) || _randomnessProvider == address(0) || _treasury == address(0)) {
            revert InvalidAddress();
        }

        usdc = IERC20(_usdc);
        randomnessProvider = IRandomnessProvider(_randomnessProvider);
        treasury = _treasury;

        // Initialize default tiers (prices in USDC with 6 decimals)
        tiers[1] = Tier({
            price: 5 * 10**6,       // 5 USDC
            minValue: 1 * 10**6,    // 1 USDC
            maxValue: 10 * 10**6,   // 10 USDC
            active: true
        });

        tiers[2] = Tier({
            price: 20 * 10**6,      // 20 USDC
            minValue: 5 * 10**6,    // 5 USDC
            maxValue: 30 * 10**6,   // 30 USDC
            active: true
        });

        tiers[3] = Tier({
            price: 50 * 10**6,      // 50 USDC
            minValue: 5 * 10**6,    // 5 USDC
            maxValue: 75 * 10**6,   // 75 USDC
            active: true
        });

        tiers[4] = Tier({
            price: 100 * 10**6,     // 100 USDC
            minValue: 10 * 10**6,   // 10 USDC
            maxValue: 150 * 10**6,  // 150 USDC
            active: true
        });
    }

    /**
     * @notice Purchase a vending machine tier
     * @param tier The tier to purchase (1, 2, 3, or 4)
     */
    function purchase(uint8 tier) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 requestId) 
    {
        if (tier == 0 || tier > MAX_TIERS) revert InvalidTier();
        
        Tier memory tierInfo = tiers[tier];
        if (!tierInfo.active) revert TierNotActive();

        // Transfer USDC from buyer to contract (not treasury)
        bool success = usdc.transferFrom(msg.sender, address(this), tierInfo.price);
        if (!success) revert InvalidPayment();

        // Request randomness
        requestId = randomnessProvider.requestRandomWords(1); // Request 1 random word

        // Store purchase info
        purchases[requestId] = Purchase({
            buyer: msg.sender,
            tier: tier,
            timestamp: block.timestamp,
            pricePaid: tierInfo.price,
            fulfilled: false,
            randomWords: new uint256[](0)
        });

        // Track VRF request timestamp
        vrfRequestTimestamp[requestId] = block.timestamp;

        // Track purchase history
        allPurchaseIds.push(requestId);
        userPurchaseIds[msg.sender].push(requestId);

        // Update stats
        userPurchaseCount[msg.sender]++;
        totalRevenue += tierInfo.price;
        totalPurchases++;

        emit PurchaseInitiated(msg.sender, tier, requestId, tierInfo.price);

        return requestId;
    }

    /**
     * @notice Fulfill randomness callback from VRF provider
     * @param requestId The request ID
     * @param randomWords Array of random numbers
     */
    function fulfillRandomness(uint256 requestId, uint256[] memory randomWords) 
        external 
    {
        require(msg.sender == address(randomnessProvider), "Only randomness provider");
        
        Purchase storage purchaseInfo = purchases[requestId];
        if (purchaseInfo.buyer == address(0)) revert PurchaseNotFound();
        if (purchaseInfo.fulfilled) revert AlreadyFulfilled();

        purchaseInfo.randomWords = randomWords;
        purchaseInfo.fulfilled = true;

        // Calculate estimated wallet value based on random seed
        Tier memory tierInfo = tiers[purchaseInfo.tier];
        uint256 estimatedValue = _calculateWalletValue(
            tierInfo.minValue,
            tierInfo.maxValue,
            randomWords[0]
        );

        emit WalletReady(
            requestId,
            purchaseInfo.buyer,
            purchaseInfo.tier,
            estimatedValue
        );
    }

    /**
     * @notice Calculate wallet value based on random seed
     * @param minValue Minimum possible value
     * @param maxValue Maximum possible value
     * @param randomSeed Random seed from VRF
     * @return Calculated wallet value
     */
    function _calculateWalletValue(
        uint256 minValue,
        uint256 maxValue,
        uint256 randomSeed
    ) internal pure returns (uint256) {
        uint256 range = maxValue - minValue + 1;
        uint256 randomValue = randomSeed % range;
        return minValue + randomValue;
    }

    /**
     * @notice Get purchase details
     * @param requestId The request ID
     * @return Purchase details
     */
    function getPurchase(uint256 requestId) 
        external 
        view 
        returns (Purchase memory) 
    {
        return purchases[requestId];
    }

    /**
     * @notice Get tier information
     * @param tier Tier number (1, 2, 3, or 4)
     * @return Tier details
     */
    function getTier(uint8 tier) external view returns (Tier memory) {
        if (tier == 0 || tier > MAX_TIERS) revert InvalidTier();
        return tiers[tier];
    }

    /**
     * @notice Get user's total purchase count
     * @param user User address
     * @return Number of purchases
     */
    function getUserPurchaseCount(address user) external view returns (uint256) {
        return userPurchaseCount[user];
    }

    /**
     * @notice Get all purchase IDs for a user
     * @param user User address
     * @return Array of request IDs
     */
    function getUserPurchaseIds(address user) external view returns (uint256[] memory) {
        return userPurchaseIds[user];
    }

    /**
     * @notice Get all purchase IDs
     * @return Array of all request IDs
     */
    function getAllPurchaseIds() external view returns (uint256[] memory) {
        return allPurchaseIds;
    }

    /**
     * @notice Get multiple purchases at once
     * @param requestIds Array of request IDs
     * @return Array of purchases
     */
    function getBatchPurchases(uint256[] calldata requestIds) 
        external 
        view 
        returns (Purchase[] memory) 
    {
        Purchase[] memory result = new Purchase[](requestIds.length);
        for (uint256 i = 0; i < requestIds.length; i++) {
            result[i] = purchases[requestIds[i]];
        }
        return result;
    }

    /**
     * @notice Get paginated purchase history
     * @param offset Starting index
     * @param limit Number of items to return
     * @return Array of purchases
     */
    function getPurchaseHistory(uint256 offset, uint256 limit) 
        external 
        view 
        returns (Purchase[] memory) 
    {
        uint256 total = allPurchaseIds.length;
        if (offset >= total) {
            return new Purchase[](0);
        }
        
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        
        uint256 resultLength = end - offset;
        Purchase[] memory result = new Purchase[](resultLength);
        
        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = purchases[allPurchaseIds[offset + i]];
        }
        
        return result;
    }

    // Admin functions

    /**
     * @notice Update tier parameters
     * @param tier Tier number
     * @param price Price in USDC
     * @param minValue Minimum wallet value
     * @param maxValue Maximum wallet value
     * @param active Whether tier is active
     */
    function setTierParameters(
        uint8 tier,
        uint256 price,
        uint256 minValue,
        uint256 maxValue,
        bool active
    ) external onlyOwner {
        if (tier == 0 || tier > MAX_TIERS) revert InvalidTier();
        if (minValue >= maxValue) revert InvalidTierParameters();
        if (price == 0) revert InvalidTierParameters();

        tiers[tier] = Tier({
            price: price,
            minValue: minValue,
            maxValue: maxValue,
            active: active
        });

        emit TierUpdated(tier, price, minValue, maxValue, active);
    }

    /**
     * @notice Update treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert InvalidAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Update randomness provider
     * @param newProvider New provider address
     */
    function setRandomnessProvider(address newProvider) external onlyOwner {
        if (newProvider == address(0)) revert InvalidAddress();
        randomnessProvider = IRandomnessProvider(newProvider);
    }

    /**
     * @notice Emergency: Manually fulfill purchase if VRF fails
     * @param requestId Request ID that timed out
     * @param randomSeed Manual random seed
     */
    function emergencyFulfillPurchase(uint256 requestId, uint256 randomSeed) 
        external 
        onlyOwner 
    {
        require(vrfRequestTimestamp[requestId] != 0, "Invalid request ID");
        if (block.timestamp < vrfRequestTimestamp[requestId] + VRF_CALLBACK_TIMEOUT) {
            revert VRFTimeoutNotReached();
        }

        Purchase storage purchaseInfo = purchases[requestId];
        if (purchaseInfo.buyer == address(0)) revert PurchaseNotFound();
        if (purchaseInfo.fulfilled) revert AlreadyFulfilled();

        // Mark as fulfilled with manual seed
        purchaseInfo.fulfilled = true;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomSeed;
        purchaseInfo.randomWords = randomWords;

        // Calculate wallet value
        Tier memory tierInfo = tiers[purchaseInfo.tier];
        uint256 estimatedValue = _calculateWalletValue(
            tierInfo.minValue,
            tierInfo.maxValue,
            randomSeed
        );

        emit EmergencyFulfillment(requestId, estimatedValue);
        emit WalletReady(
            requestId,
            purchaseInfo.buyer,
            purchaseInfo.tier,
            estimatedValue
        );
    }

    /**
     * @notice Emergency: Refund purchase if VRF fails and owner decides to refund
     * @param requestId Request ID to refund
     */
    function emergencyRefundPurchase(uint256 requestId) 
        external 
        onlyOwner 
    {
        require(vrfRequestTimestamp[requestId] != 0, "Invalid request ID");
        if (block.timestamp < vrfRequestTimestamp[requestId] + VRF_CALLBACK_TIMEOUT) {
            revert VRFTimeoutNotReached();
        }

        Purchase storage purchaseInfo = purchases[requestId];
        if (purchaseInfo.buyer == address(0)) revert PurchaseNotFound();
        if (purchaseInfo.fulfilled) revert AlreadyFulfilled();

        // Mark as fulfilled to prevent re-entry
        purchaseInfo.fulfilled = true;

        // Refund the buyer from contract balance
        bool success = usdc.transfer(purchaseInfo.buyer, purchaseInfo.pricePaid);
        require(success, "Refund failed");

        emit PurchaseRefunded(requestId, purchaseInfo.buyer, purchaseInfo.pricePaid);
    }

    /**
     * @notice Withdraw collected revenue to treasury
     * @param amount Amount of USDC to withdraw
     */
    function withdrawRevenue(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert InvalidTierParameters();
        
        uint256 balance = usdc.balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");

        bool success = usdc.transfer(treasury, amount);
        require(success, "Transfer failed");

        emit RevenueWithdrawn(treasury, amount);
    }

    /**
     * @notice Get contract's USDC balance
     * @return USDC balance
     */
    function getUSDCBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
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
     * @notice Emergency withdraw (only if stuck funds)
     * @param token Token address (address(0) for ETH)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(treasury).transfer(amount);
        } else {
            IERC20(token).transfer(treasury, amount);
        }
    }
}
