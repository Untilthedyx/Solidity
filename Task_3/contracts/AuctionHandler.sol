// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";

library AuctionHandler {
    using PriceConverter for uint256;

    struct Auction {
        address seller;
        uint256 startPrice;
        uint256 startTime;
        uint256 duration;
        bool isended;
        uint256 highestBid;
        address highestBidder;
        address nftAddress;
        uint256 nftId;
        address tokenAddress;
        uint256 feePercentage;
    }

    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 amount, address tokenAddress);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 amount);
    event FeeCollected(uint256 indexed _auctionId, uint256 _feeAmount, address _tokenAddress);

    function placeBid(uint256 _auctionId, uint256 _amount,address _tokenAddress, mapping(uint256 => Auction) storage auctions, AggregatorV3Interface ethPriceFeed, mapping(address => AggregatorV3Interface) storage priceFeeds, address contractAddress) external  {
        Auction storage auction = auctions[_auctionId];
        require(!auction.isended&&block.timestamp<=auction.startTime+auction.duration,"Auction has already ended");
        
        uint256 payValue = PriceConverter.convertToUSD(_amount, _tokenAddress, ethPriceFeed, priceFeeds);
        uint256 startPriceValue = PriceConverter.convertToUSD(auction.startPrice, auction.tokenAddress, ethPriceFeed, priceFeeds);
        uint256 highestBidValue = PriceConverter.convertToUSD(auction.highestBid, auction.tokenAddress, ethPriceFeed, priceFeeds);
        

        require(payValue>=startPriceValue&&payValue>highestBidValue,"Bid too low");

        if(_tokenAddress==address(0)){
            require(msg.value==_amount,"ETH amount mismatch");

        }else {
            IERC20(_tokenAddress).transferFrom(msg.sender,contractAddress,_amount);
        }

        if(auction.highestBidder!=address(0)){
            if(auction.tokenAddress == address(0)){
                payable (auction.highestBidder).transfer(auction.highestBid);
            }else{
                IERC20(auction.tokenAddress).transfer(auction.highestBidder,auction.highestBid);
            }
        }

        auction.highestBidder=msg.sender;
        auction.highestBid=_amount;
        auction.tokenAddress=_tokenAddress;

        emit BidPlaced(_auctionId,msg.sender, _amount,_tokenAddress);
    }

    function endAuction(uint256 _auctionId, mapping(uint256 => Auction) storage auctions,address feeCollector, address contractAddress) external {
        Auction storage auction = auctions[_auctionId];
        require(!auction.isended, "Auction already ended");

        auction.isended =true;
        
        if(auction.highestBidder!=address(0)){
            uint256 feeAmount =(auction.highestBid*auction.feePercentage)/10000;
            uint256 sellerAmount = auction.highestBid-feeAmount;

            IERC721(auction.nftAddress).safeTransferFrom(contractAddress, auction.highestBidder,auction.nftId);

            if(auction.tokenAddress==address(0)){
               payable (auction.seller).transfer(sellerAmount);
               payable (feeCollector).transfer(feeAmount);
            }else{
               IERC20(auction.tokenAddress).transfer(auction.seller,sellerAmount);
               IERC20(auction.tokenAddress).transfer(feeCollector,feeAmount);
            }

            emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
            emit FeeCollected(_auctionId, feeAmount, auction.tokenAddress);
        }else{
            IERC721(auction.nftAddress).safeTransferFrom(contractAddress,auction.seller, auction.nftId);
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }
}