// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
     function convertToUSD(uint256 _amount, address _tokenAddress, AggregatorV3Interface ethPriceFeed, mapping(address => AggregatorV3Interface) storage priceFeeds) internal view returns (uint256){
        AggregatorV3Interface priceFeed = _tokenAddress==address(0)?ethPriceFeed:priceFeeds[_tokenAddress];

        (, int price,,,) = priceFeed.latestRoundData();
        require(price>0,"Invalid price");

        uint8 decimals = priceFeed.decimals();
        return (_amount * uint256(price))/(10**decimals);
    }

    function calculateDynamicFee(uint256 amount, address tokenAddress, AggregatorV3Interface ethPriceFeed, mapping(address=>AggregatorV3Interface) storage priceFeeds, uint256 baseFeePercentage, uint256 minFeePercentage, uint256 maxFeePercentage) public view returns(uint256) {
        uint256 usdValue = convertToUSD(amount, tokenAddress, ethPriceFeed, priceFeeds);

        if(usdValue< 1000*1e18){
            return maxFeePercentage;
        }else if(usdValue < 10000*1e18){
            return baseFeePercentage;
        }else{
            return minFeePercentage;
        }
    }
}