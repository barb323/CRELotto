// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IReceiver} from "src/interfaces/IReceiver.sol";

/// @notice Minimal Forwarder nur für lokale Tests
contract MockKeystoneForwarder {
    event ReportProcessed(address indexed receiver, bool success);

    /// @notice Ruft onReport auf dem Receiver auf – fertig.
    function report(address receiver, bytes calldata reportData) external {
        // metadata kann leer sein (ReceiverTemplate prüft nur msg.sender)
        bytes memory emptyMetadata = "";

        (bool success, bytes memory returnData) = receiver.call(
            abi.encodeWithSelector(
                IReceiver.onReport.selector,
                emptyMetadata,
                reportData
            )
        );

        emit ReportProcessed(receiver, success);

        if (!success) {
            // Originalen Error weiterleiten (Custom Error bleibt erhalten)
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }
}
