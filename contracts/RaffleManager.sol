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
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 ticketsSold;
        uint256 prizePool;
        address winner;
        bool completed;
        uint256 startTime;
        uint256 endTime;
    }

    struct TicketPurchase {
        address buyer;
        uint256[] ticketNumbers;
        uint256 timestamp;
    }

    // State variables
    IERC20 public immutable usdc;
    IRandomnessProvider public randomnessProvider;
    
    uint256 public constant TICKET_PRICE = 1 * 10**6; // 1 USDC
    uint256 public constant MAX_TICKETS_PER_USER = 5;
    uint256 public constant HOUSE_FEE_PERCENT = 10; // 10% house edge
    
    Raffle public currentRaffle;
    mapping(uint256 => Raffle) public raffleHistory;
    mapping(uint256 => address[]) public raffleTicketHolders; // raffleId => ticket holders
    mapping(uint256 => mapping(address => uint256)) public userTicketCount; // raffleId => user => count
    mapping(uint256 => TicketPurchase[]) public rafflePurchases; // raffleId => purchases
    mapping(uint256 => uint256) public vrfRequestToRaffle; // VRF requestId => raffleId
    
    address public treasury;
    uint256 public totalRaffles;
    uint256 public defaultMaxTickets = 100;

    // Events
    event RaffleStarted(uint256 indexed raffleId, uint256 maxTickets, uint256 ticketPrice);
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
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    // Errors
    error InvalidAmount();
    error ExceedsMaxTickets();
    error RaffleAlreadyFilled();
    error RaffleNotFilled();
    error InvalidAddress();
    error TransferFailed();

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

        // Start first raffle
        _startNewRaffle();
    }

    /**
     * @notice Buy raffle tickets
     * @param amount Number of tickets to buy (1-5)
     */
    function buyTickets(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256[] memory ticketNumbers) 
    {
        if (amount == 0 || amount > MAX_TICKETS_PER_USER) revert InvalidAmount();
        if (currentRaffle.completed) revert RaffleAlreadyFilled();
        
        uint256 userCurrentTickets = userTicketCount[currentRaffle.raffleId][msg.sender];
        if (userCurrentTickets + amount > MAX_TICKETS_PER_USER) revert ExceedsMaxTickets();

        uint256 remainingTickets = currentRaffle.maxTickets - currentRaffle.ticketsSold;
        if (amount > remainingTickets) revert ExceedsMaxTickets();

        // Calculate total cost
        uint256 totalCost = TICKET_PRICE * amount;

        // Transfer USDC from buyer
        bool success = usdc.transferFrom(msg.sender, address(this), totalCost);
        if (!success) revert TransferFailed();

        // Assign ticket numbers
        ticketNumbers = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            uint256 ticketNumber = currentRaffle.ticketsSold + i;
            ticketNumbers[i] = ticketNumber;
            raffleTicketHolders[currentRaffle.raffleId].push(msg.sender);
        }

        // Update raffle state
        currentRaffle.ticketsSold += amount;
        currentRaffle.prizePool += totalCost;
        userTicketCount[currentRaffle.raffleId][msg.sender] += amount;

        // Store purchase
        rafflePurchases[currentRaffle.raffleId].push(TicketPurchase({
            buyer: msg.sender,
            ticketNumbers: ticketNumbers,
            timestamp: block.timestamp
        }));

        emit TicketsPurchased(currentRaffle.raffleId, msg.sender, amount, ticketNumbers);

        // If raffle is filled, request randomness
        if (currentRaffle.ticketsSold >= currentRaffle.maxTickets) {
            _finalizeRaffle();
        }

        return ticketNumbers;
    }

    /**
     * @notice Finalize raffle and request winner selection
     */
    function _finalizeRaffle() internal {
        currentRaffle.completed = true;
        currentRaffle.endTime = block.timestamp;

        emit RaffleFilled(currentRaffle.raffleId, currentRaffle.ticketsSold);

        // Request randomness for winner selection
        uint256 requestId = randomnessProvider.requestRandomWords(1);
        vrfRequestToRaffle[requestId] = currentRaffle.raffleId;
    }

    /**
     * @notice Fulfill randomness and select winner
     * @param requestId VRF request ID
     * @param randomWords Random numbers from VRF
     */
    function fulfillRandomness(uint256 requestId, uint256[] memory randomWords) 
        external 
    {
        require(msg.sender == address(randomnessProvider), "Only randomness provider");
        
        uint256 raffleId = vrfRequestToRaffle[requestId];
        Raffle storage raffle = raffleHistory[raffleId];
        
        if (raffle.raffleId == 0) {
            raffle = currentRaffle;
        }

        require(raffle.completed, "Raffle not completed");
        require(raffle.winner == address(0), "Winner already selected");

        // Select winning ticket
        uint256 winningTicket = randomWords[0] % raffle.ticketsSold;
        address winner = raffleTicketHolders[raffleId][winningTicket];

        // Calculate prize pool: 90% goes to winner (10% house fee)
        uint256 houseFee = (raffle.prizePool * HOUSE_FEE_PERCENT) / 100;
        uint256 prizePool = raffle.prizePool - houseFee;

        // Update raffle
        raffle.winner = winner;
        raffle.prizePool = prizePool;

        // Transfer prize to winner
        require(usdc.transfer(winner, prizePool), "Prize transfer failed");

        // Transfer house fee to treasury
        require(usdc.transfer(treasury, houseFee), "Fee transfer failed");

        emit WinnerSelected(raffleId, winner, winningTicket, prizePool);

        // Save to history
        raffleHistory[raffleId] = raffle;

        // Start new raffle
        _startNewRaffle();
    }

    /**
     * @notice Start a new raffle
     */
    function _startNewRaffle() internal {
        totalRaffles++;
        
        currentRaffle = Raffle({
            raffleId: totalRaffles,
            ticketPrice: TICKET_PRICE,
            maxTickets: defaultMaxTickets,
            ticketsSold: 0,
            prizePool: 0,
            winner: address(0),
            completed: false,
            startTime: block.timestamp,
            endTime: 0
        });

        emit RaffleStarted(totalRaffles, defaultMaxTickets, TICKET_PRICE);
    }

    /**
     * @notice Get current raffle info
     * @return Current raffle details
     */
    function getCurrentRaffle() external view returns (Raffle memory) {
        return currentRaffle;
    }

    /**
     * @notice Get user's tickets for current raffle
     * @param user User address
     * @return Ticket numbers
     */
    function getUserTickets(address user) 
        external 
        view 
        returns (uint256[] memory) 
    {
        TicketPurchase[] memory purchases = rafflePurchases[currentRaffle.raffleId];
        uint256 totalTickets = userTicketCount[currentRaffle.raffleId][user];
        
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
     * @notice Get raffle history
     * @param raffleId Raffle ID
     * @return Raffle details
     */
    function getRaffle(uint256 raffleId) external view returns (Raffle memory) {
        return raffleHistory[raffleId];
    }

    // Admin functions

    /**
     * @notice Set default max tickets for new raffles
     * @param _maxTickets New max tickets
     */
    function setDefaultMaxTickets(uint256 _maxTickets) external onlyOwner {
        require(_maxTickets > 0, "Invalid max tickets");
        defaultMaxTickets = _maxTickets;
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
