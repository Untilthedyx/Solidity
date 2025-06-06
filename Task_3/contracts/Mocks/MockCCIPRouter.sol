// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

contract MockCCIPRouter {
    event MessageSent(bytes32 indexed messageId, uint64 indexed destinationChainSelector);

    function ccipSend(uint64 destinationChainSelector, Client.EVM2AnyMessage memory message) external payable returns(bytes32){
        bytes32 messageId = keccak256(abi.encode(destinationChainSelector,message,block.timestamp));

        emit MessageSent(messageId,destinationChainSelector);

        return messageId;
    }

    function getFee(uint64 , Client.EVM2AnyMessage memory ) external pure returns(uint256){
        return 0.01 ether;
    }
}