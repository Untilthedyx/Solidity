// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IntToRoman{
    struct IntAndRoman{
        uint num;
        string roman; 
    }

    
IntAndRoman[] private  romanInts;

constructor(){
        romanInts.push(IntAndRoman(1000,"M"));
        romanInts.push(IntAndRoman(900,"CM"));
        romanInts.push(IntAndRoman(500,"D"));
        romanInts.push(IntAndRoman(400,"CD"));
        romanInts.push(IntAndRoman(100,"C"));
        romanInts.push(IntAndRoman(90,"XC"));
        romanInts.push(IntAndRoman(50,"L"));
        romanInts.push(IntAndRoman(40,"XL"));
        romanInts.push(IntAndRoman(10,"X"));
        romanInts.push(IntAndRoman(9,"IX"));
        romanInts.push(IntAndRoman(5,"V"));
        romanInts.push(IntAndRoman(4,"IV"));
        romanInts.push(IntAndRoman(1,"I"));
}

    
    function intToRoman1(uint n)public view  returns(string  memory){  
        bytes memory result;
        for(uint i=0;i<romanInts.length;i++){
            for (;n>=romanInts[i].num;){
                n-=romanInts[i].num;
                result=abi.encodePacked(result,romanInts[i].roman);
            }
            if (n==0) break;
        }
        return string(result);
    }

    string[] private thousands =["","M","MM","MMM"];
    string[] private hundreds =["", "C", "CC", "CCC", "CD", "D", "DC", "DCC", "DCCC", "CM"];
    string[] private tens =["", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC"];
    string[] private ones =["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"];

    function intToRoman2(uint n)public view returns(string memory){
        return string(abi.encodePacked(thousands[n / 1000],hundreds[n % 1000 / 100],tens[n % 100 / 10],ones[n % 10]));
    }
}