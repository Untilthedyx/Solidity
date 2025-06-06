// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import  {IRouterClient} from"@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import "./AuctionHandler.sol";


library CrossChainHandler {

    struct CrossChainBid{
        uint64 sourceChainId;
        address bidder;
        uint256 amount;
        uint256 auctionId;
        address tokenAddress;
        bool executed;
    }

    struct CCIPStorage{
        mapping (bytes32 => CrossChainBid)  crossChainBids;
        mapping (uint64 => bool)  allowedSourceChains;
        IRouterClient  ccipRouter;
    }

    event CrossChainBidReceived(bytes32 indexed messageId, uint64 sourceChainId, address bidder, uint256 amount);
    event CrossChainBidExecuted(bytes32 indexed messageId,uint256 auctionId);
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 amount, address tokenAddress);

     function initializeCCIP(CCIPStorage storage self, address _ccipRouter) internal{
        self.ccipRouter = IRouterClient(_ccipRouter);

        self.allowedSourceChains[1]=true;//Ethereum
        self.allowedSourceChains[43114]=true;//Avalanche
        self.allowedSourceChains[137]=true; //Polygon
        self.allowedSourceChains[56]=true;//BSC
    }

     function sendCrossChainBid(CCIPStorage storage self, uint64 _destinationChainId, uint256 _auctionId, uint256 _amount,address _tokenAddress,address contractAddress) internal returns (bytes32){
        require(address(self.ccipRouter)!=address(0),"CCIP not configured");

        if(_tokenAddress!=address(0)){
            IERC20(_tokenAddress).transferFrom(msg.sender,contractAddress,_amount);
        }else{
            require(msg.value>=_amount,"Insufficient ETH for bid");
        }
        
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage(
            {
                receiver: abi.encode(contractAddress),
                data:abi.encode( msg.sender,_auctionId,_amount,_tokenAddress),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                feeToken: address(0),
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1(
                    {
                        gasLimit: 200000
                    }
                ))
            }
        );

        uint256 ccipFee = self.ccipRouter.getFee(_destinationChainId,message);

        if(_tokenAddress==address(0)){
            require(msg.value>=ccipFee+_amount,"Insufficient ETH for bid and CCIP fee");
        }else{
            require(msg.value>=ccipFee,"Insufficient ETH for CCIP fee");
        }
        //发送CCIP消息
        bytes32 messageId = self.ccipRouter.ccipSend{value:msg.value}(_destinationChainId,message);
        //记录跨链出价信息
        self.crossChainBids[messageId] = CrossChainBid({
            sourceChainId: 0,
            bidder:msg.sender,
            amount:_amount,
            auctionId:_auctionId,
            tokenAddress:_tokenAddress,
            executed:false
        });

        return messageId;
    }

    function receiveCrossChainMessage(CCIPStorage storage self,Client.Any2EVMMessage memory message) internal returns (bytes32) {
        require(self.allowedSourceChains[message.sourceChainSelector],"Invalid source chain");

        (address bidder, uint256 auctionId, uint256 amount, address tokenAddress )= abi.decode(message.data,(address,uint256,uint256,address));

        //记录跨链出价信息
        self.crossChainBids[message.messageId] = CrossChainBid({
            sourceChainId: message.sourceChainSelector,
            bidder:bidder,
            amount:amount,
            auctionId:auctionId,
            tokenAddress:tokenAddress,
            executed:false
        });

        emit CrossChainBidReceived(message.messageId, message.sourceChainSelector, bidder, amount);
        return message.messageId;
    }

    function executeCrossChainBid(CCIPStorage storage self, bytes32 messageId,mapping(uint256 => AuctionHandler.Auction) storage auctions,AggregatorV3Interface ethPriceFeed,mapping(address => AggregatorV3Interface) storage priceFeeds) internal {
        CrossChainBid memory bid = self.crossChainBids[messageId];
        require(!bid.executed,"Bid already executed");

        AuctionHandler.Auction storage auction = auctions[bid.auctionId];
        if(auction.isended||block.timestamp>auction.startTime+auction.duration){
            self.crossChainBids[messageId].executed = true;
            return;
        }

        uint256 bidValue = PriceConverter.convertToUSD(bid.amount, bid.tokenAddress, ethPriceFeed, priceFeeds);
        uint256 startPriceValue = PriceConverter.convertToUSD(auction.startPrice, auction.tokenAddress, ethPriceFeed, priceFeeds);
        uint256 highestBidValue = PriceConverter.convertToUSD(auction.highestBid, auction.tokenAddress, ethPriceFeed, priceFeeds);

        if(bidValue>=startPriceValue&&bidValue>highestBidValue){
            if(auction.highestBidder!=address(0)){
                if(auction.tokenAddress==address(0)){
                    payable (auction.highestBidder).transfer(auction.highestBid);
                }else{
                    IERC20(auction.tokenAddress).transfer(auction.highestBidder,auction.highestBid);
                }
            }

            auction.highestBidder=bid.bidder;
            auction.highestBid=bid.amount;
            auction.tokenAddress=bid.tokenAddress;

            emit BidPlaced(bid.auctionId, bid.bidder, bid.amount, bid.tokenAddress);
        }

        self.crossChainBids[messageId].executed = true;
        emit CrossChainBidExecuted(messageId, bid.auctionId);
    }

    function markBidExecuted(CCIPStorage storage self, bytes32 messageId) internal {
        require(!self.crossChainBids[messageId].executed,"Bid already executed");
        self.crossChainBids[messageId].executed = true;
        emit CrossChainBidExecuted(messageId,self.crossChainBids[messageId].auctionId);
    }

    function getCrossChainBid(CCIPStorage storage self, bytes32 messageId) internal view returns(CrossChainBid memory){
        return self.crossChainBids[messageId];
    }

     function setAllowedSourceChain(CCIPStorage storage self,uint64 chainId, bool allowed) internal{
        self.allowedSourceChains[chainId] = allowed;
    }

    function setCCIPRouter(CCIPStorage storage self,address _ccipRouter) internal {
        self.ccipRouter = IRouterClient(_ccipRouter);
    }

    function isSourceChainAllowde(CCIPStorage storage self,uint64 chainId)internal view returns(bool ) {
        return self.allowedSourceChains[chainId];
    }

}