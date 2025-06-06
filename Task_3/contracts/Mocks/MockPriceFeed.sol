// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockPriceFeed{
    int256 private price;
    uint8 private _decimals;

    constructor(){
        price = 200000000000;
        _decimals = 8;
    }

    function latestRoundData() external view returns(uint80 roundId,int256 answer,uint256 startedAt,uint256 updatedAt,uint80 answeredInRound){
        return (1,price,block.timestamp,block.timestamp,1);
    }

    function decimals() external view returns(uint8){
        return _decimals;
    }

    function setPrice(int256 _price) external{
        price = _price;
    }
}