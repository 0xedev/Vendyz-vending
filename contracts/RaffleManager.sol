// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IRandomnessProvider.sol";

/**
 * @title RaffleManager
 * @notice Manages raffle ticket sales and winner selection
 * @dev Users buy tickets (max 5 per wallet), winner selected when raffle fills
 */
contract RaffleManager is Ownable, ReentrancyGuard, Pausable {
    
    // Structs
    struct Raffle {
        uint256 raffleId;
        address creator;
        address tokenAddress;
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 minTickets;
        uint256 ticketsSold;
        uint256 prizePool;
        address winner;
        bool completed;
        bool cancelled;
        uint256 startTime;
        uint256 endTime;
        uint256 duration;
    }

    struct TicketPurchase {
        address buyer;
        uint256[] ticketNumbers;
        uint256 timestamp;
    }

    // State variables
    IERC20 public immutable usdc; // Kept for backward compatibility
    IRandomnessProvider public randomnessProvider;
    
    uint256 public constant MAX_TICKETS_PER_USER = 5;
    uint256 public houseFeePercent = 10; // 10% house edge (configurable)
    uint256 public constant MAX_HOUSE_FEE_PERCENT = 20; // Maximum 20%
    uint256 public constant MIN_RAFFLE_DURATION = 1 hours;
    uint256 public constant MAX_RAFFLE_DURATION = 30 days;
    uint256 public constant MIN_TICKET_PRICE = 1; // Minimum 1 token unit
    uint256 public constant VRF_CALLBACK_TIMEOUT = 1 hours; // Time before emergency intervention allowed
    
    mapping(uint256 => Raffle) public raffles;
    mapping(uint256 => address[]) public raffleTicketHolders; // raffleId => ticket holders
    mapping(uint256 => mapping(address => uint256)) public userTicketCount; // raffleId => user => count
    mapping(uint256 => TicketPurchase[]) public rafflePurchases; // raffleId => purchases
    mapping(uint256 => uint256) public vrfRequestToRaffle; // VRF requestId => raffleId
    mapping(uint256 => uint256) public vrfRequestTimestamp; // VRF requestId => timestamp
    mapping(uint256 => address[]) public raffleParticipants; // raffleId => unique participants
    mapping(uint256 => mapping(address => bool)) public isParticipant; // raffleId => user => hasParticipated
    
    address public treasury;
    uint256 public totalRaffles;
    uint256[] public activeRaffleIds;

    // Events
    event RaffleCreated(
        uint256 indexed raffleId,
        address indexed creator,
        uint256 maxTickets,
        uint256 minTickets,
        uint256 duration,
        uint256 endTime
    );
    event TicketsPurchased(
        uint256 indexed raffleId,
        address indexed buyer,
        uint256 amount,
        uint256[] ticketNumbers
    );
    event RaffleFilled(uint256 indexed raffleId, uint256 totalTickets);
    event WinnerSelected(
        uint256 indexed raffleId,
        address indexed winner,
        uint256 winningTicket,
        uint256 prizePool
    );
    event RaffleCancelled(uint256 indexed raffleId, uint256 refundAmount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event HouseFeeUpdated(uint256 oldFee, uint256 newFee);
    event EmergencyWinnerSet(uint256 indexed raffleId, address indexed winner);
    event TokensRecovered(address indexed token, address indexed to, uint256 amount);

    // Errors
    error InvalidAmount();
    error InvalidFeePercent();
    error ExceedsMaxTickets();
    error RaffleAlreadyFilled();
    error RaffleNotFilled();
    error InvalidAddress();
    error TransferFailed();
    error InvalidDuration();
    error InvalidTicketConfig();
    error RaffleNotActive();
    error RaffleStillActive();
    error MinimumNotMet();
    error Unauthorized();

    /**
     * @notice Constructor
     * @param _usdc USDC token address
     * @param _randomnessProvider Chainlink VRF provider
     * @param _treasury Treasury address
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
    }

    /**
     * @notice Create a new raffle
     * @param tokenAddress ERC20 token address for raffle tickets
     * @param ticketPrice Price per ticket in token units
     * @param maxTickets Maximum number of tickets
     * @param minTickets Minimum tickets required to proceed (else refund)
     * @param duration Duration in seconds
     */
    function createRaffle(
        address tokenAddress,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 minTickets,
        uint256 duration
    ) external nonReentrant whenNotPaused returns (uint256) {
        if (tokenAddress == address(0)) revert InvalidAddress();
        if (ticketPrice < MIN_TICKET_PRICE) revert InvalidAmount();
        if (duration < MIN_RAFFLE_DURATION || duration > MAX_RAFFLE_DURATION) {
            revert InvalidDuration();
        }
        if (minTickets == 0 || minTickets > maxTickets) {
            revert InvalidTicketConfig();
        }
        if (maxTickets == 0) {
            revert InvalidTicketConfig();
        }

        totalRaffles++;
        uint256 raffleId = totalRaffles;

        raffles[raffleId] = Raffle({
            raffleId: raffleId,
            creator: msg.sender,
            tokenAddress: tokenAddress,
            ticketPrice: ticketPrice,
            maxTickets: maxTickets,
            minTickets: minTickets,
            ticketsSold: 0,
            prizePool: 0,
            winner: address(0),
            completed: false,
            cancelled: false,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            duration: duration
        });

        activeRaffleIds.push(raffleId);

        emit RaffleCreated(
            raffleId,
            msg.sender,
            maxTickets,
            minTickets,
            duration,
            block.timestamp + duration
        );

        return raffleId;
    }

    /**
     * @notice Buy raffle tickets
     * @param raffleId ID of raffle to buy tickets for
     * @param amount Number of tickets to buy (1-5)
     */
    function buyTickets(uint256 raffleId, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256[] memory ticketNumbers) 
    {
        if (amount == 0 || amount > MAX_TICKETS_PER_USER) revert InvalidAmount();
        
        Raffle storage raffle = raffles[raffleId];
        if (raffle.raffleId == 0) revert RaffleNotActive();
        if (raffle.completed || raffle.cancelled) revert RaffleAlreadyFilled();
        if (block.timestamp >= raffle.endTime) revert RaffleNotActive();
        
        uint256 userCurrentTickets = userTicketCount[raffleId][msg.sender];
        if (userCurrentTickets + amount > MAX_TICKETS_PER_USER) revert ExceedsMaxTickets();

        uint256 remainingTickets = raffle.maxTickets - raffle.ticketsSold;
        if (amount > remainingTickets) revert ExceedsMaxTickets();

        // Calculate total cost using raffle's token and price
        uint256 totalCost = raffle.ticketPrice * amount;
        IERC20 token = IERC20(raffle.tokenAddress);

        // Transfer tokens from buyer
        bool success = token.transferFrom(msg.sender, address(this), totalCost);
        if (!success) revert TransferFailed();

        // Assign ticket numbers
        ticketNumbers = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            uint256 ticketNumber = raffle.ticketsSold + i;
            ticketNumbers[i] = ticketNumber;
            raffleTicketHolders[raffleId].push(msg.sender);
        }

        // Update raffle state
        raffle.ticketsSold += amount;
        raffle.prizePool += totalCost;
        userTicketCount[raffleId][msg.sender] += amount;

        // Track unique participants
        if (!isParticipant[raffleId][msg.sender]) {
            raffleParticipants[raffleId].push(msg.sender);
            isParticipant[raffleId][msg.sender] = true;
        }

        // Store purchase
        rafflePurchases[raffleId].push(TicketPurchase({
            buyer: msg.sender,
            ticketNumbers: ticketNumbers,
            timestamp: block.timestamp
        }));

        emit TicketsPurchased(raffleId, msg.sender, amount, ticketNumbers);

        // If raffle is filled, finalize it
        if (raffle.ticketsSold >= raffle.maxTickets) {
            _finalizeRaffle(raffleId);
        }

        return ticketNumbers;
    }

    /**
     * @notice Finalize raffle (either filled or time expired with min tickets met)
     * @param raffleId ID of raffle to finalize
     */
    function finalizeRaffle(uint256 raffleId) external nonReentrant {
        Raffle storage raffle = raffles[raffleId];
        if (raffle.raffleId == 0) revert RaffleNotActive();
        if (msg.sender != raffle.creator) revert Unauthorized();
        if (raffle.completed || raffle.cancelled) revert RaffleAlreadyFilled();
        
        bool isFilled = raffle.ticketsSold >= raffle.maxTickets;
        bool isExpired = block.timestamp >= raffle.endTime;
        
        if (!isFilled && !isExpired) revert RaffleStillActive();
        
        // Check if minimum tickets met
        if (raffle.ticketsSold < raffle.minTickets) {
            _cancelAndRefund(raffleId);
            return;
        }
        
        _finalizeRaffle(raffleId);
    }

    /**
     * @notice Internal finalize raffle and request winner selection
     */
    function _finalizeRaffle(uint256 raffleId) internal {
        Raffle storage raffle = raffles[raffleId];
        raffle.completed = true;
        if (raffle.endTime > block.timestamp) {
            raffle.endTime = block.timestamp;
        }

        emit RaffleFilled(raffleId, raffle.ticketsSold);

        // Request randomness for winner selection
        uint256 requestId = randomnessProvider.requestRandomWords(1);
        vrfRequestToRaffle[requestId] = raffleId;
        vrfRequestTimestamp[requestId] = block.timestamp;
    }

    /**
     * @notice Cancel raffle and refund all participants
     */
    function _cancelAndRefund(uint256 raffleId) internal {
        Raffle storage raffle = raffles[raffleId];
        raffle.cancelled = true;
        
        IERC20 token = IERC20(raffle.tokenAddress);
        address[] memory participants = raffleParticipants[raffleId];
        
        // Refund each unique participant once
        for (uint256 i = 0; i < participants.length; i++) {
            address buyer = participants[i];
            uint256 ticketCount = userTicketCount[raffleId][buyer];
            
            if (ticketCount > 0) {
                uint256 refundAmount = ticketCount * raffle.ticketPrice;
                userTicketCount[raffleId][buyer] = 0;
                
                bool success = token.transfer(buyer, refundAmount);
                if (!success) revert TransferFailed();
            }
        }
        
        _removeFromActiveRaffles(raffleId);
        emit RaffleCancelled(raffleId, raffle.prizePool);
    }

    /**
     * @notice Fulfill randomness and select winner
     * @param requestId VRF request ID
     * @param randomWords Random numbers from VRF
     */
    function fulfillRandomness(uint256 requestId, uint256[] memory randomWords) 
        external nonReentrant
    {
        require(msg.sender == address(randomnessProvider), "Only randomness provider");
        
        uint256 raffleId = vrfRequestToRaffle[requestId];
        Raffle storage raffle = raffles[raffleId];

        require(raffle.completed, "Raffle not completed");
        require(raffle.winner == address(0), "Winner already selected");

        // Select winning ticket
        uint256 winningTicket = randomWords[0] % raffle.ticketsSold;
        address winner = raffleTicketHolders[raffleId][winningTicket];

        // Calculate prize pool using configurable house fee
        uint256 houseFee = (raffle.prizePool * houseFeePercent) / 100;
        uint256 prizeAmount = raffle.prizePool - houseFee;

        // Update raffle
        raffle.winner = winner;

        IERC20 token = IERC20(raffle.tokenAddress);

        // Transfer prize to winner
        require(token.transfer(winner, prizeAmount), "Prize transfer failed");

        // Transfer house fee to treasury
        require(token.transfer(treasury, houseFee), "Fee transfer failed");

        emit WinnerSelected(raffleId, winner, winningTicket, prizeAmount);

        // Remove from active raffles
        _removeFromActiveRaffles(raffleId);
    }

    /**
     * @notice Remove raffle from active list
     */
    function _removeFromActiveRaffles(uint256 raffleId) internal {
        for (uint256 i = 0; i < activeRaffleIds.length; i++) {
            if (activeRaffleIds[i] == raffleId) {
                activeRaffleIds[i] = activeRaffleIds[activeRaffleIds.length - 1];
                activeRaffleIds.pop();
                break;
            }
        }
    }

    /**
     * @notice Get raffle details
     * @param raffleId Raffle ID
     * @return Raffle details
     */
    function getRaffle(uint256 raffleId) external view returns (Raffle memory) {
        return raffles[raffleId];
    }

    /**
     * @notice Get all active raffle IDs
     * @return Array of active raffle IDs
     */
    function getActiveRaffles() external view returns (uint256[] memory) {
        return activeRaffleIds;
    }

    /**
     * @notice Get user's tickets for a raffle
     * @param raffleId Raffle ID
     * @param user User address
     * @return Ticket numbers
     */
    function getUserTickets(uint256 raffleId, address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        TicketPurchase[] memory purchases = rafflePurchases[raffleId];
        uint256 totalTickets = userTicketCount[raffleId][user];
        
        uint256[] memory tickets = new uint256[](totalTickets);
        uint256 index = 0;
        
        for (uint256 i = 0; i < purchases.length; i++) {
            if (purchases[i].buyer == user) {
                for (uint256 j = 0; j < purchases[i].ticketNumbers.length; j++) {
                    tickets[index] = purchases[i].ticketNumbers[j];
                    index++;
                }
            }
        }
        
        return tickets;
    }

    /**
     * @notice Get user's ticket count for a raffle
     * @param raffleId Raffle ID
     * @param user User address
     * @return Number of tickets
     */
    function getUserTicketCount(uint256 raffleId, address user) 
        external 
        view 
        returns (uint256) 
    {
        return userTicketCount[raffleId][user];
    }

    // Admin functions

    /**
     * @notice Emergency: Set winner manually if VRF fails
     * @param requestId VRF request ID that timed out
     * @param winnerIndex Index of winner in ticket holders array
     */
    function emergencySetWinner(uint256 requestId, uint256 winnerIndex) 
        external 
        onlyOwner 
        nonReentrant
    {
        uint256 raffleId = vrfRequestToRaffle[requestId];
        require(raffleId != 0, "Invalid request ID");
        require(vrfRequestTimestamp[requestId] != 0, "No VRF request");
        require(
            block.timestamp >= vrfRequestTimestamp[requestId] + VRF_CALLBACK_TIMEOUT,
            "VRF timeout not reached"
        );

        Raffle storage raffle = raffles[raffleId];
        require(raffle.completed, "Raffle not completed");
        require(raffle.winner == address(0), "Winner already selected");
        require(winnerIndex < raffle.ticketsSold, "Invalid winner index");

        address winner = raffleTicketHolders[raffleId][winnerIndex];

        // Calculate prize pool using configurable house fee
        uint256 houseFee = (raffle.prizePool * houseFeePercent) / 100;
        uint256 prizeAmount = raffle.prizePool - houseFee;

        raffle.winner = winner;

        IERC20 token = IERC20(raffle.tokenAddress);

        require(token.transfer(winner, prizeAmount), "Prize transfer failed");
        require(token.transfer(treasury, houseFee), "Fee transfer failed");

        emit EmergencyWinnerSet(raffleId, winner);
        emit WinnerSelected(raffleId, winner, winnerIndex, prizeAmount);

        _removeFromActiveRaffles(raffleId);
    }

    /**
     * @notice Emergency: Refund raffle if VRF fails
     * @param requestId VRF request ID that timed out
     */
    function emergencyRefundRaffle(uint256 requestId) 
        external 
        onlyOwner 
        nonReentrant
    {
        uint256 raffleId = vrfRequestToRaffle[requestId];
        require(raffleId != 0, "Invalid request ID");
        require(vrfRequestTimestamp[requestId] != 0, "No VRF request");
        require(
            block.timestamp >= vrfRequestTimestamp[requestId] + VRF_CALLBACK_TIMEOUT,
            "VRF timeout not reached"
        );

        Raffle storage raffle = raffles[raffleId];
        require(raffle.completed, "Raffle not completed");
        require(raffle.winner == address(0), "Winner already selected");

        _cancelAndRefund(raffleId);
    }

    /**
     * @notice Update house fee percentage
     * @param newFeePercent New fee percentage (max 20%)
     */
    function setHouseFeePercent(uint256 newFeePercent) external onlyOwner {
        if (newFeePercent > MAX_HOUSE_FEE_PERCENT) revert InvalidFeePercent();
        uint256 oldFee = houseFeePercent;
        houseFeePercent = newFeePercent;
        emit HouseFeeUpdated(oldFee, newFeePercent);
    }

    /**
     * @notice Recover accidentally sent tokens
     * @param token Token address to recover
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function rescueTokens(address token, address to, uint256 amount) 
        external 
        onlyOwner 
    {
        if (token == address(0) || to == address(0)) revert InvalidAddress();
        require(IERC20(token).transfer(to, amount), "Transfer failed");
        emit TokensRecovered(token, to, amount);
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
}
