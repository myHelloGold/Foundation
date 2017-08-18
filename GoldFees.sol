pragma solidity ^0.4.11;

import "./inc/SafeMath.sol";
import "./inc/Ownable.sol";

contract GoldFees is SafeMath,Ownable {
    // e.g. if rate = 0.0054
    //uint rateN = 9999452055;
    uint rateN = 9999452054794520548;
    uint rateD = 19;
    uint public maxDays;
    uint public maxRate;

    
    function GoldFees() {
        calcMax();
    }

    function calcMax() {
        maxDays = 1;
        maxRate = rateN;
        
        
        uint pow = 2;
        do {
            uint newN = rateN ** pow;
            if (newN / maxRate != maxRate) {
                maxDays = pow / 2;
                break;
            }
            maxRate = newN;
            pow *= 2;
        } while (pow < 2000);
        
    }

    function updateRate(uint256 _n, uint256 _d) onlyOwner{
        rateN = _n;
        rateD = _d;
        calcMax();
    }
    
    function rateForDays(uint256 numDays) constant returns (uint256 rate) {
        if (numDays <= maxDays) {
            uint r = rateN ** numDays;
            uint d = rateD * numDays;
            if (d > 18) {
                uint div =  10 ** (d-18);
                rate = r / div;
            } else {
                div = 10 ** (18 - d);
                rate = r * div;
            }
        } else {
            uint256 md1 = numDays / 2;
            uint256 md2 = numDays - md1;
             uint256 r2;

            uint256 r1 = rateForDays(md1);
            if (md1 == md2) {
                r2 = r1;
            } else {
                r2 = rateForDays(md2);
            }
           

            //uint256 r1 = rateForDays(maxDays);
            //uint256 r2 = rateForDays(numDays-maxDays);
            rate  = safeMul( r1 , r2)  / 10 ** 18;
        }
        return; 
        
    }

    uint256 constant public UTC2MYT = 1483200000;

    function wotDay(uint256 time) returns (uint256) {
        return (time - UTC2MYT) / (1 days);
    }

    // minimum fee is 1 unless same day
    function calcFees(uint256 start, uint256 end, uint256 startAmount) constant returns (uint256 amount, uint256 fee) {
        if (startAmount == 0) return;
        uint256 numberOfDays = wotDay(end) - wotDay(start);
        if (numberOfDays == 0) {
            amount = startAmount;
            return;
        }
        amount = (rateForDays(numberOfDays) * startAmount) / (1 ether);
        if ((fee == 0) && (amount !=  0)) amount--;
        fee = safeSub(startAmount,amount);
    }
}