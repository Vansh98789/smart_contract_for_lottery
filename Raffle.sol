// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "./KeeperCompatibleInterface.sol"; // Self-made

/*
 * @title A sample Raffle Contract
 * @author  Vansh Maheshwari
 * @notice  this is for creating an untamperable decentralized smart contracat
 * @dev this implement chainlinik VRF V2 and chainlink keepers
 */
error Raffle__NotEnoughETHEntered();
error Raffle_TransferFailer();
error Raffle_NotOpen();
error Raffle_UpkeepNotNeeded(uint256 currentBalance,uint256 numPlayers,uint256 raffleState);
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    // Type declaration
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    uint256 private immutable s_entrancefee;
    address payable[] private players; // Make it payable to receive money
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    /* Events */
    event RafleEnter(address indexed player);
    event RequestdRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    // Lottery variables
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    constructor(
        address vrfCoordinatorV2,
        uint256 entracefee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        s_entrancefee = entracefee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp; // Fixed typo
        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value < s_entrancefee) {
            revert Raffle__NotEnoughETHEntered();
        }
        players.push(payable(msg.sender));
        emit RafleEnter(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */)
        public
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval); // Fixed typo
        bool hasPlayer = (players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayer && hasBalance);
    }

    function performUpkeep(bytes calldata /*perform data*/) external override {
        (bool upkeepNeeded, )=checkUpkeep("");
        if(!upkeepNeeded){
          revert Raffle_UpkeepNotNeeded(address(this).balance,players.length,uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestdRaffleWinner(requestId);
    }

    function fulfillRandomWords(
    uint256, /* requestId */
    uint256[] memory randomWords
) internal override {
    uint256 indexofWinner = randomWords[0] % players.length;
    address payable recentWinner = players[indexofWinner];
    s_recentWinner = recentWinner;
    s_raffleState = RaffleState.OPEN;
    players = new address payable[](0) ; //ed initialization
    s_lastTimeStamp=block.timestamp;
    (bool success, ) = recentWinner.call{value: address(this).balance}("");
    if (!success) {
        revert Raffle_TransferFailer();
    }
    emit WinnerPicked(recentWinner);
}


    /* View / Pure functions */
    function getEntranceFee() public view returns (uint256) {
        return s_entrancefee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return players[index];
    }

    function getrecentWinner() public view returns (address) {
        return s_recentWinner;
    }
    function getRaffleState() public view returns (RaffleState){
        return s_raffleState;
    }
    function getNumWords() public pure returns (uint256){
        return NUM_WORDS;
    }
    function getNumberofPlayers()public view returns(uint256){
        return players.length;  
    }
    function getLatestTimeStamp() public view returns(uint256){
        return s_lastTimeStamp;
    }
    function getRequestConfirmation() public pure returns(uint256){
        return REQUEST_CONFIRMATIONS;
    }
}
