// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SponsorAuction
 * @notice Manages 30-day recurring auctions for sponsored token placements
 * @dev Projects bid USDC for guaranteed placement in vending machine wallets
 */
contract SponsorAuction is Ownable, ReentrancyGuard, Pausable {
    
    // Structs
    struct Auction {
        uint256 auctionId;
        uint256 startTime;
        uint256 endTime;
        uint256 availableSlots;
        address[] winners;
        uint256[] winningBids;
        bool finalized;
    }

    struct Bid {
        address bidder;
        address tokenAddress;
        uint256 amount;
        uint256 timestamp;
        bool active;
    }

    // State variables
    IERC20 public immutable usdc;
    
    uint256 public constant AUCTION_DURATION = 30 days;
    uint256 public constant SPONSOR_SLOTS = 5; // 5 sponsors per cycle
    uint256 public constant MIN_BID = 100 * 10**6; // 100 USDC minimum
    
    Auction public currentAuction;
    mapping(uint256 => Auction) public auctionHistory;
    mapping(uint256 => Bid[]) public auctionBids; // auctionId => bids
    mapping(address => uint256) public activeBids; // bidder => current bid amount
    
    address public treasury;
    uint256 public totalAuctions;
    address[] public activeSponsors;
    mapping(address => bool) public isSponsor;
    mapping(address => uint256) public sponsorEndTime;

    // Events
    event AuctionStarted(uint256 indexed auctionId, uint256 startTime, uint256 endTime);
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        address indexed tokenAddress,
        uint256 amount
    );
    event BidUpdated(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 oldAmount,
        uint256 newAmount
    );
    event BidRefunded(address indexed bidder, uint256 amount);
    event AuctionFinalized(
        uint256 indexed auctionId,
        address[] winners,
        uint256[] winningBids
    );
    event SponsorAdded(address indexed tokenAddress, uint256 endTime);
    event SponsorRemoved(address indexed tokenAddress);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    // Errors
    error AuctionNotActive();
    error AuctionNotEnded();
    error AuctionAlreadyFinalized();
    error BidTooLow();
    error InvalidAddress();
    error TransferFailed();
    error NoBidToUpdate();
    error InvalidBidAmount();

    /**
     * @notice Constructor
     * @param _usdc USDC token address
     * @param _treasury Treasury address for winning bids
     */
    constructor(address _usdc, address _treasury) {
        if (_usdc == address(0) || _treasury == address(0)) {
            revert InvalidAddress();
        }

        usdc = IERC20(_usdc);
        treasury = _treasury;

        // Start first auction
        _startNewAuction();
    }

    /**
     * @notice Place a bid for sponsor placement
     * @param tokenAddress Address of token to sponsor
     * @param bidAmount Bid amount in USDC
     */
    function placeBid(address tokenAddress, uint256 bidAmount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        if (tokenAddress == address(0)) revert InvalidAddress();
        if (block.timestamp >= currentAuction.endTime) revert AuctionNotActive();
        if (bidAmount < MIN_BID) revert BidTooLow();

        uint256 currentBid = activeBids[msg.sender];
        
        if (currentBid > 0) {
            // Update existing bid
            if (bidAmount <= currentBid) revert InvalidBidAmount();
            
            uint256 additionalAmount = bidAmount - currentBid;
            
            // Transfer additional USDC
            bool success = usdc.transferFrom(msg.sender, address(this), additionalAmount);
            if (!success) revert TransferFailed();
            
            // Update bid in array
            _updateBidAmount(msg.sender, bidAmount);
            
            emit BidUpdated(currentAuction.auctionId, msg.sender, currentBid, bidAmount);
        } else {
            // New bid
            bool success = usdc.transferFrom(msg.sender, address(this), bidAmount);
            if (!success) revert TransferFailed();
            
            // Store bid
            auctionBids[currentAuction.auctionId].push(Bid({
                bidder: msg.sender,
                tokenAddress: tokenAddress,
                amount: bidAmount,
                timestamp: block.timestamp,
                active: true
            }));
            
            emit BidPlaced(currentAuction.auctionId, msg.sender, tokenAddress, bidAmount);
        }
        
        activeBids[msg.sender] = bidAmount;
    }

    /**
     * @notice Update bid amount in the bids array
     * @param bidder Address of bidder
     * @param newAmount New bid amount
     */
    function _updateBidAmount(address bidder, uint256 newAmount) internal {
        Bid[] storage bids = auctionBids[currentAuction.auctionId];
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].bidder == bidder && bids[i].active) {
                bids[i].amount = newAmount;
                bids[i].timestamp = block.timestamp;
                return;
            }
        }
    }

    /**
     * @notice Finalize auction and select winners
     * @dev Can be called by anyone after auction ends
     */
    function finalizeAuction() external nonReentrant {
        if (block.timestamp < currentAuction.endTime) revert AuctionNotEnded();
        if (currentAuction.finalized) revert AuctionAlreadyFinalized();

        Bid[] storage bids = auctionBids[currentAuction.auctionId];
        
        // Sort bids by amount (descending) and get top SPONSOR_SLOTS
        Bid[] memory sortedBids = _sortBids(bids);
        
        uint256 winnerCount = sortedBids.length > SPONSOR_SLOTS 
            ? SPONSOR_SLOTS 
            : sortedBids.length;
        
        address[] memory winners = new address[](winnerCount);
        uint256[] memory winningBids = new uint256[](winnerCount);
        
        // Clear previous sponsors
        _clearSponsors();
        
        // Process winners and losers
        for (uint256 i = 0; i < sortedBids.length; i++) {
            if (i < winnerCount) {
                // Winner: transfer bid to treasury and add as sponsor
                winners[i] = sortedBids[i].tokenAddress;
                winningBids[i] = sortedBids[i].amount;
                
                usdc.transfer(treasury, sortedBids[i].amount);
                
                // Add to active sponsors
                activeSponsors.push(sortedBids[i].tokenAddress);
                isSponsor[sortedBids[i].tokenAddress] = true;
                sponsorEndTime[sortedBids[i].tokenAddress] = block.timestamp + AUCTION_DURATION;
                
                emit SponsorAdded(sortedBids[i].tokenAddress, sponsorEndTime[sortedBids[i].tokenAddress]);
            } else {
                // Loser: refund bid
                usdc.transfer(sortedBids[i].bidder, sortedBids[i].amount);
                emit BidRefunded(sortedBids[i].bidder, sortedBids[i].amount);
            }
            
            // Clear active bid
            activeBids[sortedBids[i].bidder] = 0;
        }
        
        // Update auction
        currentAuction.winners = winners;
        currentAuction.winningBids = winningBids;
        currentAuction.finalized = true;
        
        emit AuctionFinalized(currentAuction.auctionId, winners, winningBids);
        
        // Save to history
        auctionHistory[currentAuction.auctionId] = currentAuction;
        
        // Start new auction
        _startNewAuction();
    }

    /**
     * @notice Sort bids by amount (descending)
     * @param bids Array of bids to sort
     * @return Sorted array of bids
     */
    function _sortBids(Bid[] storage bids) internal view returns (Bid[] memory) {
        Bid[] memory sortedBids = new Bid[](bids.length);
        
        // Copy active bids
        uint256 count = 0;
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].active) {
                sortedBids[count] = bids[i];
                count++;
            }
        }
        
        // Resize array to actual count
        Bid[] memory activeBids = new Bid[](count);
        for (uint256 i = 0; i < count; i++) {
            activeBids[i] = sortedBids[i];
        }
        
        // Simple bubble sort (fine for small arrays)
        for (uint256 i = 0; i < activeBids.length; i++) {
            for (uint256 j = i + 1; j < activeBids.length; j++) {
                if (activeBids[j].amount > activeBids[i].amount) {
                    Bid memory temp = activeBids[i];
                    activeBids[i] = activeBids[j];
                    activeBids[j] = temp;
                }
            }
        }
        
        return activeBids;
    }

    /**
     * @notice Clear previous sponsors
     */
    function _clearSponsors() internal {
        for (uint256 i = 0; i < activeSponsors.length; i++) {
            isSponsor[activeSponsors[i]] = false;
            emit SponsorRemoved(activeSponsors[i]);
        }
        delete activeSponsors;
    }

    /**
     * @notice Start a new auction
     */
    function _startNewAuction() internal {
        totalAuctions++;
        
        currentAuction = Auction({
            auctionId: totalAuctions,
            startTime: block.timestamp,
            endTime: block.timestamp + AUCTION_DURATION,
            availableSlots: SPONSOR_SLOTS,
            winners: new address[](0),
            winningBids: new uint256[](0),
            finalized: false
        });
        
        emit AuctionStarted(totalAuctions, currentAuction.startTime, currentAuction.endTime);
    }

    /**
     * @notice Get current auction info
     * @return Current auction details
     */
    function getCurrentAuction() external view returns (Auction memory) {
        return currentAuction;
    }

    /**
     * @notice Get all bids for current auction
     * @return Array of bids
     */
    function getCurrentBids() external view returns (Bid[] memory) {
        return auctionBids[currentAuction.auctionId];
    }

    /**
     * @notice Get active sponsors
     * @return Array of sponsored token addresses
     */
    function getActiveSponsors() external view returns (address[] memory) {
        return activeSponsors;
    }

    /**
     * @notice Check if token is currently sponsored
     * @param tokenAddress Token address to check
     * @return Whether token is sponsored
     */
    function isTokenSponsored(address tokenAddress) external view returns (bool) {
        return isSponsor[tokenAddress] && sponsorEndTime[tokenAddress] > block.timestamp;
    }

    /**
     * @notice Get auction history
     * @param auctionId Auction ID
     * @return Auction details
     */
    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctionHistory[auctionId];
    }

    /**
     * @notice Get user's current bid
     * @param user User address
     * @return Current bid amount
     */
    function getUserBid(address user) external view returns (uint256) {
        return activeBids[user];
    }

    /**
     * @notice Get time remaining in current auction
     * @return Seconds remaining
     */
    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= currentAuction.endTime) {
            return 0;
        }
        return currentAuction.endTime - block.timestamp;
    }

    // Admin functions

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
     * @notice Manually add sponsor (for partnerships, etc.)
     * @param tokenAddress Token address to sponsor
     * @param duration Sponsor duration in seconds
     */
    function addManualSponsor(address tokenAddress, uint256 duration) 
        external 
        onlyOwner 
    {
        if (tokenAddress == address(0)) revert InvalidAddress();
        
        activeSponsors.push(tokenAddress);
        isSponsor[tokenAddress] = true;
        sponsorEndTime[tokenAddress] = block.timestamp + duration;
        
        emit SponsorAdded(tokenAddress, sponsorEndTime[tokenAddress]);
    }

    /**
     * @notice Remove sponsor manually
     * @param tokenAddress Token address to remove
     */
    function removeSponsor(address tokenAddress) external onlyOwner {
        isSponsor[tokenAddress] = false;
        
        // Remove from active sponsors array
        for (uint256 i = 0; i < activeSponsors.length; i++) {
            if (activeSponsors[i] == tokenAddress) {
                activeSponsors[i] = activeSponsors[activeSponsors.length - 1];
                activeSponsors.pop();
                break;
            }
        }
        
        emit SponsorRemoved(tokenAddress);
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
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        usdc.transfer(treasury, amount);
    }
}
