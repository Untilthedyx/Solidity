// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable}from"@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable}from"@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import "./CrossChainHandler.sol";
import "./PriceConverter.sol";
import "./AuctionHandler.sol";


contract NFTAuction is UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable{
    using CrossChainHandler for CrossChainHandler.CCIPStorage;
    using PriceConverter for uint256;
    using AuctionHandler for mapping(uint256 => AuctionHandler.Auction);
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    CrossChainHandler.CCIPStorage private ccipStorage;

    address public ccipRouterAddress;
    

    //拍卖结构体

    mapping(uint256 => AuctionHandler.Auction) public auctions;
    // address public admin;
    uint256 public nextAuctionId;

    AggregatorV3Interface public ethPriceFeed;
    mapping (address=>AggregatorV3Interface) public priceFeeds;

    uint256 public baseFeePercentage;
    uint256 public maxFeePercentage;
    uint256 public minFeePercentage;
    address public feeCollector;

    

    event AuctionCreated(uint256 indexed auctionId, address indexed seller,address nftAddress, uint256 nftId);

    

    function initialize(address _ccipRouter,address _ethPriceFeed,address admin) public initializer{
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        ethPriceFeed=AggregatorV3Interface(_ethPriceFeed);
        ccipRouterAddress = _ccipRouter;
        ccipStorage.initializeCCIP( _ccipRouter);
        feeCollector = admin;

        baseFeePercentage = 250;
        maxFeePercentage = 500;
        minFeePercentage = 100;
    }

    function setPriceFeed(address _priceFeedAddress, address tokenAddress) external onlyRole(ADMIN_ROLE) {
        priceFeeds[tokenAddress]=AggregatorV3Interface(_priceFeedAddress);
    }

    //设置手续费参数
    function setFeeParamters(uint256 _baseFeePercentage, uint256 _minFeePercentage,uint256 _maxFeePercentage, address _feeCollector) external onlyRole(ADMIN_ROLE) {
        require(_minFeePercentage<=_baseFeePercentage&&_baseFeePercentage<=_maxFeePercentage,"Invalid fee range");
        require(_maxFeePercentage<=1000,"Max fee too high");
        
        
        baseFeePercentage = _baseFeePercentage;
        minFeePercentage = _minFeePercentage;
        maxFeePercentage = _maxFeePercentage;
        feeCollector = _feeCollector;
    }

    //计算动态手续费
    function calculateDynamicFee(uint256 amount, address tokenAddress) public view returns(uint256){
        return PriceConverter.calculateDynamicFee(amount, tokenAddress, ethPriceFeed, priceFeeds, baseFeePercentage, minFeePercentage, maxFeePercentage);
    }



    
    //创建拍卖
    function createAuction (uint256 _duration, uint256 _startPrice, address _nftAddress, uint256 _nftId, address _tokenAddress) external whenNotPaused nonReentrant{
        require(_duration>=100,"Auction duration needs to be at least 100s");
        require(_startPrice>0,"Start price must be greater than 0");
        require(_tokenAddress == address(0)||address(priceFeeds[_tokenAddress])!= address(0),"Token price feed not configured");
        
        IERC721 nft = IERC721(_nftAddress);
        require(nft.ownerOf(_nftId)==msg.sender,"NFT not owned by the sender");
        require(nft.isApprovedForAll(msg.sender, address(this))|| nft.getApproved(_nftId)==address(this),"NFT not approved for auction");

        nft.transferFrom(msg.sender, address(this),_nftId);

        uint256 feePercentage = calculateDynamicFee(_startPrice, _tokenAddress);


        auctions[nextAuctionId]=AuctionHandler.Auction(
            {
                seller:msg.sender,
                startPrice:_startPrice,
                startTime:block.timestamp,
                duration:_duration,
        
                isended:false,
                highestBid:0,
                highestBidder:address(0),
                
                nftAddress:_nftAddress,
                nftId:_nftId,
                tokenAddress:_tokenAddress,

                feePercentage:feePercentage
            }
        );
        emit AuctionCreated(nextAuctionId,msg.sender,_nftAddress,_nftId);
        nextAuctionId++;
        
    }
    //出价
    function placeBid(uint256 _auctionId, uint256 _amount,address _tokenAddress) external payable whenNotPaused nonReentrant{
       AuctionHandler.placeBid(_auctionId, _amount, _tokenAddress,auctions, ethPriceFeed, priceFeeds, address(this));
    }
    //结束拍卖
    function endAuction(uint256 _auctionId) external nonReentrant{
       AuctionHandler.Auction storage auction = auctions[_auctionId];
       require(msg.sender == auction.seller||block.timestamp > auction.startTime + auction.duration||hasRole(ADMIN_ROLE,msg.sender),"Not authorized or auction not expired");
       AuctionHandler.endAuction(_auctionId, auctions,feeCollector,address(this));
    }

    


    //CCIP
    //发送CCIP消息
    function sendCrossChainBid(uint64 _destinationChainId, uint256 _auctionId, uint256 _amount, address _tokenAddress) external payable whenNotPaused  nonReentrant {
        ccipStorage.sendCrossChainBid(_destinationChainId, _auctionId, _amount, _tokenAddress,address(this));
    }
    //接收CCIP消息
    function ccipReceive(Client.Any2EVMMessage memory message) external{
        require(msg.sender == ccipRouterAddress, "Only CCIP router can call");
        bytes32 messageId = ccipStorage.receiveCrossChainMessage(message);
        ccipStorage.executeCrossChainBid(messageId, auctions, ethPriceFeed, priceFeeds);
    }

    //手动执行跨链出价
    function executeCrossChainBid(bytes32 messageId) external nonReentrant {
        ccipStorage.executeCrossChainBid(messageId, auctions, ethPriceFeed, priceFeeds);
    }

    function setAllowedSourceChain(uint64 chainId, bool allowed) external onlyRole(ADMIN_ROLE) {
        ccipStorage.setAllowedSourceChain(chainId, allowed);
    }

    function setCCIPRouter(address _ccipRouter) external onlyRole(ADMIN_ROLE) {
        ccipStorage.setCCIPRouter(_ccipRouter);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function emergencyWithdraw(address tokenAddress, uint256 amount) external onlyRole(ADMIN_ROLE){
        if(tokenAddress==address(0)){
            payable (msg.sender).transfer(amount);
        }else{
            IERC20(tokenAddress).transfer(msg.sender,amount);
        }
    }

    function emergencyWithdrawNFT(address nftAddress, uint256 nftId) external onlyRole(ADMIN_ROLE){
        IERC721(nftAddress).transferFrom(address(this),msg.sender,nftId);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    receive() external payable {}
    fallback() external payable {}
}