//SPDX-License-Identifier: MIT

// version
pragma solidity ^0.8.20;

// imports
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {ReceiverTemplate} from "./interfaces/ReceiverTemplate.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Sample Raffle Contract
 * @author Waldemar Barbe
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */

contract MyLottery is ReceiverTemplate {
    /*Errors*/
    error Raffle__SendExactEntranceFee();
    error Raffle__NotEnoughTimeHasPassed();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState,
        bool s_mintwoPlayer
    );

    /*Type Declarations*/
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /*State Variables*/
    IVRFCoordinatorV2Plus public s_vrfCoordinator;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev the duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState; // start as open
    // Zeigt ob mindestens zwei verschiedene spieler sind
    bool private s_mintwoPlayer = false;
    uint256 public s_storedValue;
    // Sepolia coordinator.//für testzwecke
    //address public vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    // The gas lane to use, which specifies the maximum gas price to bump to.
    //bytes32 public s_keyHash =
    //    0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    /*Events*/
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    // Constructor requires forwarder address
    constructor(
        address _forwarderAddress,
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) ReceiverTemplate(_forwarderAddress) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        s_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator); // ← hier wird der Coordinator gesetzt
    }

    function enterRaffle() external payable {
        console.log("Hello!!!");
        console.log(msg.value);
        //require(msg.value >= i_entranceFee, "Not enough ETH!"); zu viel Gas verbrauch
        //require(msg.value >= i_entranceFee, Raffle__SendMoreToEnterRaffle());
        if (msg.value < i_entranceFee || msg.value > i_entranceFee) {
            revert Raffle__SendExactEntranceFee();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // Mindest-Zwei-Spieler-Prüfung
        if (s_mintwoPlayer == false && s_players.length >= 1) {
            if (s_players[0] != msg.sender) {
                s_mintwoPlayer = true;
            }
        }

        s_players.push(payable(msg.sender));
        //1. Makes migration easier
        //2. Makes front end "indexing" easier
        emit RaffleEntered(msg.sender);
    }

    //When should the winner be picked?
    /**
     Nach bestimmten zeitinterwall wird der gewinner gelost.
     Anforderung. Mindestens zwei lose oder spieler, zeit vergangen,Raffle ist open,
     geld ist da,
     */
    function checkUpkeep() public view returns (bool upkeepNeeded) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 1;
        //s_mintwoPlayer mindestens zwei verschiedene spieler

        upkeepNeeded = (timeHasPassed &&
            isOpen &&
            hasBalance &&
            hasPlayers &&
            s_mintwoPlayer);
        return (upkeepNeeded);
    }

    // 1. get a random number
    // 2. Use ranndom number to pick a player
    // 3. wird mit cre automatisch aufgerufen über den Forwarder
    //in der production schutz einbauen z.B. WorkflowId AutorAdresse
    function _processReport(bytes calldata report) internal override {
        uint256 newValue = abi.decode(report, (uint256));
        s_storedValue = newValue;

        bool upkeepNeeded = checkUpkeep();
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState),
                s_mintwoPlayer
            );
        }

        //lotto beim berechnen
        s_raffleState = RaffleState.CALCULATING;
        //get our random number 2.5
        // 1. Request RNG
        // 2. Get RNG
        //Random Number anfordern
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash, //Gas Lane
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        //Is this redundant?
        emit RequestedRaffleWinner(requestId);
    }

    /*************************************************************** */
    //         Die Zufallszahl empfangen (Callback)                //
    /*************************************************************** */
    // Diese Funktion wird vom VRF-Coordinator aufgerufen
    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) external {
        // Sicherheit: Nur der echte Coordinator darf das aufrufen!
        if (msg.sender != address(s_vrfCoordinator)) {
            revert("Only VRF Coordinator can fulfill");
        }
        // Weiterleiten an deine interne Logik
        fulfillRandomWords(requestId, randomWords);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal {
        // Deine bisherige Logik
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_mintwoPlayer = false; //mindestens zwei spieler zurücksetzen

        emit WinnerPicked(s_recentWinner);

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    /**
     * @notice Gibt die aktuelle Anzahl der registrierten Spieler zurück
     */
    function getNumberOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }
}
