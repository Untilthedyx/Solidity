// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 二分查找 (Binary Search)
// 题目描述：在一个有序数组中查找目标值。

contract BinarySearch{
    function binarySearch(int256[] memory arr,int256 num) public pure returns (int256){
        uint low = 0;
        uint high = arr.length - 1;

        while (low < high){
            uint mid = (high+low)/2;
            if(num<arr[mid]){
                high = mid-1;
            }else if(num > arr[mid]){
                low = mid + 1;
            }else{
                return int256(mid);
            }
        }
        return -1;
    }
}