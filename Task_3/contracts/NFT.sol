// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NFT is ERC721,ERC721URIStorage,AccessControl{
    uint256 public tokenCounter;
    // address public owner;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // modifier onlyOwner() {
    //     require(msg.sender == owner, "Only the owner can call this function");
    //     _;
    // }

    constructor() ERC721("MyNFT", "NFT") {
        // owner = msg.sender;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }


    function mintNFT(address to, string memory _tokenURI) external onlyRole(MINTER_ROLE){
        
        _safeMint(to, tokenCounter);
        _setTokenURI(tokenCounter, _tokenURI);
        tokenCounter++;

    }

    // 添加铸造者角色
    function addMinter(address minter) external onlyRole(ADMIN_ROLE) {
        grantRole(MINTER_ROLE, minter);
    }
    
    // 移除铸造者角色
    function removeMinter(address minter) external onlyRole(ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, minter);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage,AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    

}