// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyLottery} from "../src/MyLottery.sol";
import {MockKeystoneForwarder} from "../test/mocks/MockKeystoneForwarder.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployLocal is Script {
    function run()
        public
        returns (MyLottery, HelperConfig, MockKeystoneForwarder)
    {
        return deployContract();
    }

    function deployContract()
        public
        returns (MyLottery, HelperConfig, MockKeystoneForwarder)
    {
        HelperConfig helperConfig = new HelperConfig(); // Erstellt eine neue Instanz
        //local -> deploy mocks, get local config
        HelperConfig.NetworkConfig memory config = helperConfig
            .getAnvilconfig();

        if (config.subscriptionId == 0) {
            //create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription
                .createSubscription(config.vrfCoordinator, config.account);

            console.log("subscriptionId:", config.subscriptionId);

            //Fund it! Geld einzahlen
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link,
                config.account
            );
        }

        // Wichtig: Config zurück speichern!
        helperConfig.setLocalConfig(config);

        vm.startBroadcast();
        MockKeystoneForwarder forwarder = new MockKeystoneForwarder(); //CRE Mock Forwarder
        //MyLottery Contract
        MyLottery lottery = new MyLottery(
            address(forwarder),
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );

        console.log("Forwarder:", address(forwarder));
        console.log("Lottery  :", address(lottery));
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        //dont need to broadcast, weil geschieht in addConsumer
        addConsumer.addConsumer(
            address(lottery),
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );

        return (lottery, helperConfig, forwarder);
    }
}
