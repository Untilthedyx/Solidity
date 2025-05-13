// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 创建一个名为Voting的合约，包含以下功能：
// 一个mapping来存储候选人的得票数
// 一个vote函数，允许用户投票给某个候选人
// 一个getVotes函数，返回某个候选人的得票数
// 一个resetVotes函数，重置所有候选人的得票数

contract Voting{
    mapping (string=>int256) public   votes;
    string[] public  candidates;

    function vote(string memory candidateName)public {
        votes[candidateName]++;
        for (uint i=0; i<candidates.length; i++) 
        {
            if (keccak256(abi.encodePacked(candidates[i])) == keccak256(abi.encodePacked(candidateName))) return;
        }
        candidates.push(candidateName);
    }

    function getVotes(string memory candidateName)public view returns (int256){
        return votes[candidateName];
    }

    function resetVotes()public{
        for (uint i=0; i<candidates.length; i++) 
        {
            votes[candidates[i]] = 0;
        }
    }
}