//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    /* VRF Mock Values*/
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    //Link / Eth price
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;

    function getSepoliaconfig() public returns (NetworkConfig memory) {
        //check to see if we set an active network config
        //prüfen ob schon config existiert
        //Die if-Bedingung verhindert nur, dass die Mocks mehrmals deployed werden.
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, //30seconds
            vrfCoordinator: vm.envAddress("VRF_COORDINATOR"),
            //doesn't matter
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: vm.envUint("SUBSCRIPTION_ID"), //might have to fix this
            callbackGasLimit: 500000, //500000 gas
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: vm.envAddress("ACCOUNT")
        });
        return localNetworkConfig;
    }

    function setLocalConfig(NetworkConfig memory newConfig) public {
        localNetworkConfig = newConfig;
    }

    function getAnvilconfig() public returns (NetworkConfig memory) {
        //check to see if we set an active network config
        //prüfen ob schon config existiert
        //Die if-Bedingung verhindert nur, dass die Mocks mehrmals deployed werden.
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        //Deploy mocks and such
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
                MOCK_BASE_FEE,
                MOCK_GAS_PRICE_LINK,
                MOCK_WEI_PER_UNIT_LINK
            );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, //30seconds
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            //doesn't matter
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0, //might have to fix this
            callbackGasLimit: 500000, //500000 gas
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}
