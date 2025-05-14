// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RomanToInt {

    mapping (bytes1 => int256) private romanMap;
    constructor(){
        romanMap["I"]=1;
        romanMap["V"]=5;
        romanMap["X"]=10;
        romanMap["L"]=50;
        romanMap["C"]=100;
        romanMap["D"]=500;
        romanMap["M"]=1000;
    }
    function romanToInt(string memory s) public view returns (int256) {
        bytes memory roman =bytes(s);
        int256  result=0;
        for (uint i=0;i<roman.length;i++){
            if(i<roman.length-1 && romanMap[roman[i]]<romanMap[roman[i+1]])result-=romanMap[roman[i]];
            else result+=romanMap[roman[i]];
        }
        return result;
    }
}