// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 反转字符串 (Reverse String)
// 题目描述：反转一个字符串。输入 "abcde"，输出 "edcba"

contract ReverseString {
    function reverseString(string memory str) public pure returns (string memory){
        bytes memory str0=bytes(str);
        bytes memory result = new bytes(str0.length);
        for (uint i=0;i<result.length;i++){
            result[i]= str0[result.length-i-1];
        }
        return string(result);
    } 
}