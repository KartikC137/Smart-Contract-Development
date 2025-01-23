// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Decentralized Lottery
 * @author Kartik Kumbhar
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreEthToEnter();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    /*Type Declarations*/
    enum RaffleState {
        OPEN, // 0
        CALCULATING_WINNER // 1
    }

    /* State variables */
    uint256 private immutable i_entranceFee;
    // @dev time between two raffles
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_firstTimeStamp;
    address private s_recentWinner;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    RaffleState private s_raffleState;

    /* Events */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /* Modifiers */

    /* Functions */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_firstTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // Legacy: require(msg.value >= i_entranceFee,"Send More Eth to Enter Raffle");
        // Newest Method (>0.8.19, most gas effiecient):
        // require(msg.value >= i_entranceFee, SendMoreEthToEnter());
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreEthToEnter();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        } // When winner is being selected, no one can enter

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // When should the winner be picked?
    /**
     * @dev This function is used to check if the contract needs to perform any upkeep
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The Time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The Contract has ETH (has players)
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if its time to restart the lottery
     * @return - ignored
     */

    function checkUpKeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_firstTimeStamp) >
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING_WINNER;

        // get a random number from chainlink VRF
        // 1. Request random number
        // 2. Get random number
        // @dev basically requestRandomWords function has 1 parameter which is of struct datatype,
        // @dev so we need to create and pass the struct object VRFV2PlusClient.RandomWordsRequest as parameter
        // @dev it can be created outside and passed to s_vrfCoordinator.requestRandomWords() or passed directly as done below:

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                    // set it true to pay for VRF request with SepoliaEth instead of LINK
                )
            })
        );
        // or create a struct
        // VRFV2PlusClient.RandomWordsRequest request = VRFV2PlusClient.RandomWordsRequest({...});
        // uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RequestedRaffleWinner(requestId); // This is redundant, used only for testing
    }

    // When an abstract contract is inherited (VRFConsumerV2Plus in this case)
    // The undefined contracts marked by virtual(meant to be overriden), must be defined in child contract

    //CEI:Checks, Effects, Interactions Pattern
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal override {
        /* Checks */

        /* Effects (Internal Contract State)*/

        // if no. of s_players = 10
        // random no. we got = 12 then 12 % 10 = 2, ie 2nd is winner
        // since we got random no. between 0 to 9 i.e 10 no.s and we had 10 players
        // randomWords[0] % s_players.length would
        // return a random no. between 0 and s_players.length-1 (i.e total no. of participants)
        uint256 indexOfWinner = randomWords[0] % s_players.length; // randomWords[0] cuz we requested 1 word (numWords = 1)
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // reset players array
        s_firstTimeStamp = block.timestamp;
        emit WinnerPicked(recentWinner);

        /* Interactions (External Contract State) */
        (bool success, ) = recentWinner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    // getter functions
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getFirstTimeStamp() external view returns (uint256) {
        return s_firstTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
