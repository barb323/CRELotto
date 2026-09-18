//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployLocal} from "script/DeployLocal.s.sol";
import {MyLottery} from "src/MyLottery.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {MockKeystoneForwarder} from "test/mocks/MockKeystoneForwarder.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract LottoTest is Test, CodeConstants {
    MyLottery public mylottery;
    HelperConfig public helperConfig;
    MockKeystoneForwarder public forwarder;

    /*State Variables*/
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address public PLAYER = makeAddr("player");
    address public PLAYER2 = makeAddr("player2");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    /*Events*/
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    //setUp() Funktion: Läuft vor jedem einzelnen Test ab, um den Zustand (State) vorzubereiten.
    function setUp() external {
        // 1. Erstelle eine Instanz des Deployment-Skripts
        DeployLocal deployer = new DeployLocal();
        // 2. Führe die deploy()-Funktion aus, um den eigentlichen Contract zu starten
        (mylottery, helperConfig, forwarder) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig
            .getAnvilconfig();

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        //gibt dem Spieler im Test 10 ETH, damit er an der Lotterie teilnehmen kann.
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.deal(PLAYER2, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(mylottery.getRaffleState() == MyLottery.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWhenYouDontPayEnough() public {
        //Arrange
        vm.prank(PLAYER);
        //Act / Asset
        vm.expectRevert(MyLottery.Raffle__SendExactEntranceFee.selector);
        mylottery.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        console.log("entranceFee:", entranceFee);
        console.log("subscriptionId:", subscriptionId);
        //Arrange
        vm.prank(PLAYER);
        //Act
        mylottery.enterRaffle{value: entranceFee}();
        //Assert
        address playerRecorded = mylottery.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    /*//////////////////////////////////////////////////////////////
                              Event Test
    //////////////////////////////////////////////////////////////*/
    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectEmit(true, false, false, false, address(mylottery));
        emit RaffleEntered(PLAYER);
        //Assert
        mylottery.enterRaffle{value: entranceFee}();
    }

    function testProcessReport() public {
        //Arrange
        vm.prank(PLAYER2);
        mylottery.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER);
        mylottery.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // 1. Report-Daten encoden (genau wie im cast-Befehl)
        bytes memory report = abi.encode(uint256(2026));

        //Act
        // 2. Aufruf über den MockForwarder
        //    (entspricht dem cast send)
        //vm.prank(PLAYER); // optional, je nachdem ob der Forwarder eine Access Control hat
        MockKeystoneForwarder(forwarder).report(address(mylottery), report);

        //Assert
        // 3. Prüfen ob der Wert angekommen ist
        assertEq(mylottery.s_storedValue(), 2026); // falls die Variable public / ein Getter existiert
    }

    function testProzessReportRevertsIfCheckUpkeepIsFalse() public {
        //Arrange (Vorbereitung)
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        bool mintwoPlayer = false; //weniger als zwei spieler
        MyLottery.RaffleState rState = mylottery.getRaffleState(); //Open=0
        bytes memory report = abi.encode(uint256(2026));

        vm.prank(PLAYER);
        mylottery.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        //Act / Assert (Ausführung & Überprüfung)
        vm.expectRevert(
            abi.encodeWithSelector(
                MyLottery.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState,
                mintwoPlayer
            )
        );

        MockKeystoneForwarder(forwarder).report(address(mylottery), report);
    }

    /*//////////////////////////////////////////////////////////////
                              Modifier
    //////////////////////////////////////////////////////////////*/

    modifier raffleEntered() {
        vm.prank(PLAYER);
        mylottery.enterRaffle{value: entranceFee}();
        vm.prank(PLAYER2);
        mylottery.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //event abfangen
    function testProzessReportUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        //Act / Assert
        bytes memory report = abi.encode(uint256(2026));
        vm.recordLogs();
        MockKeystoneForwarder(forwarder).report(address(mylottery), report);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        //assert
        MyLottery.RaffleState rState = mylottery.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1); //Calculating=1
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterProzessReport(
        uint256 randomRequestId //es wird eine Zufalszahl mehrmals generiert
    ) public raffleEntered {
        //Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(mylottery)
        );
    }

    function testFulfillRandomWordsPickAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        //Arrange (Vorbereitung)
        uint256 additionalEntrants = 3; // 4 total
        uint256 startingIndex = 1;
        address expectedWinner = address(PLAYER2);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            mylottery.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = mylottery.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        //Account (Ausführung)
        bytes memory report = abi.encode(uint256(2026));
        vm.recordLogs();
        MockKeystoneForwarder(forwarder).report(address(mylottery), report);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        console.log("Hello!");

        console.log("STARTINGPLAYERBALANCE:", STARTING_PLAYER_BALANCE);
        console.log("WinnerBalance:", expectedWinner.balance);
        console.log("Playerlength:", mylottery.getNumberOfPlayers());
        console.log("requestId:", uint256(requestId));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(mylottery)
        );

        //Assert (Überprüfung)
        address recentWinner = mylottery.getRecentWinner();
        MyLottery.RaffleState raffleState = mylottery.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = mylottery.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 2);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
