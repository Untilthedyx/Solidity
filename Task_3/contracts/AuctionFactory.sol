// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "./NFTAuction.sol";

contract AuctionFactory is Pausable, Ownable{
    using Clones for address;

    ProxyAdmin public proxyAdmin;

    address public implementation;
    address[] public allAuctions;

    mapping(address => bool) public isAuctions; 

    address public defaultETHPriceFeed;
    address public defaultCCIPRouter;

    event NewAuction(address indexed auction, address indexed creator, string name);
    event ImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);

    constructor(address _implementation, address _ethPriceFeed, address _ccipRouter) Ownable(msg.sender) {
        
        implementation = _implementation;
        defaultETHPriceFeed = _ethPriceFeed;
        defaultCCIPRouter = _ccipRouter;

        proxyAdmin = new ProxyAdmin(msg.sender);
    }
    //UUPS代理
    function createAuction(string memory name) external whenNotPaused returns(address){
        address clone = implementation.clone();
        NFTAuction(payable (clone)).initialize(defaultCCIPRouter,defaultETHPriceFeed,msg.sender);

        // NFTAuction(payable(clone)).grantRole(NFTAuction(payable(clone)).DEFAULT_ADMIN_ROLE(), msg.sender);
        // NFTAuction(payable(clone)).grantRole(NFTAuction(payable(clone)).ADMIN_ROLE(), msg.sender);
        // NFTAuction(payable(clone)).grantRole(NFTAuction(payable(clone)).UPGRADER_ROLE(), msg.sender);

        allAuctions.push(clone);
        isAuctions[clone] = true;
        emit NewAuction(clone, msg.sender,name);
        return clone;
    }

    //使用透明代理
    function createAuctionWithTransparentProxy(string memory name) external whenNotPaused returns(address){
        bytes memory initData = abi.encodeWithSelector(
            NFTAuction(payable (implementation)).initialize.selector,
            defaultCCIPRouter,
            defaultETHPriceFeed,
            msg.sender
        );

        //创建透明代理
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            implementation,
            address(proxyAdmin),
            initData
        );

        address proxyAddress = address(proxy);

        // NFTAuction(payable(proxyAddress)).grantRole(NFTAuction(payable(proxyAddress)).DEFAULT_ADMIN_ROLE(), msg.sender);
        // NFTAuction(payable(proxyAddress)).grantRole(NFTAuction(payable(proxyAddress)).ADMIN_ROLE(), msg.sender);
        // NFTAuction(payable(proxyAddress)).grantRole(NFTAuction(payable(proxyAddress)).UPGRADER_ROLE(), msg.sender);

        allAuctions.push(proxyAddress);
        isAuctions[proxyAddress] = true;

        emit NewAuction(proxyAddress, msg.sender,name);
        return proxyAddress;
    }

    //更新实现合约
    function updateImplementation(address _newImplementation) external onlyOwner{
        address oldImplementation = implementation;
        implementation = _newImplementation;
        emit ImplementationUpdated(oldImplementation, _newImplementation);
    }

    function updateDefaultPriceFeed(address _ethPriceFeed) external onlyOwner {
        defaultETHPriceFeed = _ethPriceFeed;
    }

     function updateDefaultCcipRouter(address _ccipRouter) external onlyOwner {
        defaultCCIPRouter = _ccipRouter;
    }

    function getAuctions() external view returns(address[] memory){
        return allAuctions;
    }
    
    function getAuctionCount() external view returns (uint256) {
        return allAuctions.length;
    }
    
    
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}