// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 合并两个有序数组 (Merge Sorted Array)
// 题目描述：将两个有序数组合并为一个有序数组。

contract MergeSortedArray {
    function mergeSortedArray(int256[] memory arr1,int256[] memory arr2)public pure returns(int256[] memory){
        uint len = arr1.length + arr2.length;
        int256[] memory res=new int256[](len);
        uint idx1=0; 
        uint idx2=0;
        uint idx =0;
        while (idx1<arr1.length&&idx2<arr2.length){
            if(arr1[idx1]<=arr2[idx2]){
                res[idx]=arr1[idx1];
                idx++;
                idx1++;
            }else{
                res[idx]=arr2[idx2];
                idx++;
                idx1++;
            }
        }
        for(uint i=idx;i<len;i++){
            if(idx1==arr1.length){
                res[i]=arr2[idx2];
                idx2++;
            }else{
                res[i]=arr1[idx1];
                idx1++;
            }
        }
        return res;
    }
}