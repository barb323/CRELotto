//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyLottery} from "../src/MyLottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySepolia is Script {
    function run() public returns (MyLottery) {
        return deployContract();
    }

    function deployContract() public returns (MyLottery) {
        HelperConfig helperConfig = new HelperConfig(); // Erstellt eine neue Instanz

        HelperConfig.NetworkConfig memory config = helperConfig
            .getSepoliaconfig();

        address mockForwarder = vm.envAddress("FORWARDER_MOCK");
        // Startet das Broadcasting mit dem in config.account angegebenen Account
        vm.startBroadcast();
        //MyLottery Contract
        MyLottery lottery = new MyLottery(
            mockForwarder,
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );

        vm.stopBroadcast();

        // Variablen oder Adressen formatiert ausgeben
        console.log("Lottery deployed unter:", address(lottery));

        return (lottery);
    }
}
