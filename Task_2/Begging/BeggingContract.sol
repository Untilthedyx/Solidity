// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BeggingContract {
    
    mapping (address => uint256) donationETHs;

    address public owner;
    uint256 public totalDonation;
    uint256 public starttime;
    uint256 public endtime;

    struct Donorctx {
        address donor;
        uint256 amount;
    }

    Donorctx[3] private topDonors;

    
    
    modifier onlyOwner {
        require(owner==msg.sender,"Only owner");
        _;
    }

    modifier donationPeriod{
        require(block.timestamp%endtime>=starttime,"Donation close");
        _;
    }

    event Donation(address indexed donor, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);

    constructor() {
        owner=msg.sender;
        starttime= 6*3600;
        endtime = 24*3600;
    }

    function _updateTopDonors(address donor,uint256 amount) private {

        for(uint i=0;i<3;i++){
            if(amount > topDonors[i].amount){
                for(uint j=2;j>i;j--){
                    topDonors[j]=topDonors[j-1];
                }
                topDonors[i]=Donorctx(donor,amount);
                break;
            }
            
        }
    }

    function donate() public payable donationPeriod{
        require(msg.value>0,"Donation must be > 0");

        donationETHs[msg.sender]+=msg.value;
        totalDonation+=msg.value;
        
        _updateTopDonors(msg.sender,msg.value);
        emit Donation(msg.sender,msg.value);
    }




    function withdraw() public onlyOwner{
        uint256 balance =address(this).balance;
        require(balance>0,"Zero balance");

        payable(owner).transfer(balance);
        emit Withdraw(owner,balance);

    }

    function getDonation(address donor) public view returns(uint256){
        return donationETHs[donor];
    }

    function getTopDonors() public view returns(Donorctx[3] memory){
        return topDonors;
    }
}

//部署到测试网的合约地址0x73CE711ccc807dF55F3b2fb7eE7C25CBfBb8e3Db