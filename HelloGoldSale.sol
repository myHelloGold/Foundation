pragma solidity ^0.4.11;


import "./HelloGoldToken.sol";

import "./inc/Pausable.sol";
import "./inc/SafeMath.sol";
import "./inc/ERC20.sol";


/*
 * HelloGoldSale - contract for conducting the crowdsale
 *
 */
contract HelloGoldSale is Pausable, SafeMath {

  uint256 public decimals = 8;

  uint256 public startDate = 1503892800;      // Monday, August 28, 2017 12:00:00 PM GMT+08:00
  uint256 public endDate   = 1504497600;      // Monday, September 4, 2017 12:00:00 PM GMT+08:00

  uint256 tranchePeriod = 1 weeks;

  // address of HGT Token. HGT must Approve this contract to disburse 180M tokens
  HelloGoldToken          token;

  uint256 constant MaxCoinsR1      =  80 * 10**6 * 10**8;   // 180M HGT
  uint256 public coinsRemaining    =  80 * 10**6 * 10**8; 
  uint256 coinsPerTier             =  16 * 10**6 * 10**8;   // 40M HGT
  uint256 public coinsLeftInTier   =  16 * 10**6 * 10**8;

  uint256 public minimumCap        =  0;    // presale achieved

  uint256 numTiers               = 5;
  uint16  public tierNo;
  uint256 public preallocCoins;   // used for testing against cap (inc placement)
  uint256 public purchasedCoins;  // used for testing against tier pricing
  uint256 public ethRaised;
  uint256 public personalMax     = 10 ether;     // max ether per person during public sale
  uint256 public contributors;

  address public cs;
  address public multiSig;
  address public HGT_Reserve;
  
  struct csAction  {
      bool        passedKYC;
      bool        blocked;
  }

  /* This creates an array with all balances */
  mapping (address => csAction) public permissions;
  mapping (address => uint256)  public deposits;

  modifier MustBeEnabled(address x) {
      require (!permissions[x].blocked) ;
      require (permissions[x].passedKYC) ;
      
      _;
  }

  function HelloGoldSale(address _cs, address _hgt, address _multiSig, address _reserve) {
    cs          = _cs;
    token       = HelloGoldToken(_hgt);
    multiSig    = _multiSig;
    HGT_Reserve = _reserve;
  }

  // We only expect to use this to set/reset the start of the contract under exceptional circumstances
  function setStart(uint256 when_) onlyOwner {
      startDate = when_;
      endDate = when_ + tranchePeriod;
  }

  modifier MustBeCs() {
      require (msg.sender == cs) ;
      
      _;
  }


  // 1 ether = N HGT tokens 
  uint256[5] public hgtRates = [1248900000000,1196900000000,1144800000000,1092800000000,1040700000000];
                      

    /* Approve the account for operation */
    function approve(address user) MustBeCs {
        permissions[user].passedKYC = true;
    }
    
    function block(address user) MustBeCs {
        permissions[user].blocked = true;
    }

    function unblock(address user) MustBeCs {
         permissions[user].blocked = false;
    }

    function newCs(address newCs) onlyOwner {
        cs = newCs;
    }

    function setPeriod(uint256 period_) onlyOwner {
        require (!funding()) ;
        tranchePeriod = period_;
        endDate = startDate + tranchePeriod;
        if (endDate < now + tranchePeriod) {
            endDate = now + tranchePeriod;
        }
    }

    function when()  constant returns (uint256) {
        return now;
    }

  function funding() constant returns (bool) {     
    if (paused) return false;               // frozen
    if (now < startDate) return false;      // too early
    if (now > endDate) return false;        // too late
    if (coinsRemaining == 0) return false;  // no more coins
    if (tierNo >= numTiers ) return false;  // passed end of top tier. Tiers start at zero
    return true;
  }

  function success() constant returns (bool succeeded) {
    if (coinsRemaining == 0) return true;
    bool complete = (now > endDate) ;
    bool didOK = (coinsRemaining <= (MaxCoinsR1 - minimumCap)); // not even 40M Gone?? Aargh.
    succeeded = (complete && didOK)  ;  // (out of steam but enough sold) 
    return ;
  }

  function failed() constant returns (bool didNotSucceed) {
    bool complete = (now > endDate  );
    bool didBad = (coinsRemaining > (MaxCoinsR1 - minimumCap));
    didNotSucceed = (complete && didBad);
    return;
  }

  
  function () payable MustBeEnabled(msg.sender) whenNotPaused {    
    createTokens(msg.sender,msg.value);
  }

  function linkCoin(address coin) onlyOwner {
    token = HelloGoldToken(coin);
  }

  function coinAddress() constant returns (address) {
      return address(token);
  }

  // hgtRates in whole tokens per ETH
  // max individual contribution in whole ETH
  function setHgtRates(uint256 p0,uint256 p1,uint256 p2,uint256 p3,uint256 p4, uint256 _max ) onlyOwner {
              require (now < startDate) ;
              hgtRates[0]   = p0 * 10**8;
              hgtRates[1]   = p1 * 10**8;
              hgtRates[2]   = p2 * 10**8;
              hgtRates[3]   = p3 * 10**8;
              hgtRates[4]   = p4 * 10**8;
              personalMax = _max * 1 ether;           // max ETH per person
  }

  
  event Purchase(address indexed buyer, uint256 level,uint256 value, uint256 tokens);
  event Reduction(string msg, address indexed buyer, uint256 wanted, uint256 allocated);
  event MaxFunds(address sender, uint256 taken, uint256 returned);
  
  function createTokens(address recipient, uint256 value) private {
    uint256 totalTokens;
    uint256 hgtRate;
    require (funding()) ;
    require (value >= 1 finney) ;
    require (deposits[recipient] < personalMax);

    uint256 maxRefund = 0;
    if ((deposits[recipient] + value) > personalMax) {
        maxRefund = deposits[recipient] + value - personalMax;
        value -= maxRefund;
        MaxFunds(recipient,value,maxRefund);
    }  

    uint256 val = value;

    ethRaised = safeAdd(ethRaised,value);
    if (deposits[recipient] == 0) contributors++;
    
    
    do {
      hgtRate = hgtRates[tierNo];                 // hgtRate must include the 10^8
      uint tokens = safeMul(val, hgtRate);      // (val in eth * 10^18) * #tokens per eth
      tokens = safeDiv(tokens, 1 ether);      // val is in ether, msg.value is in wei
   
      if (tokens <= coinsLeftInTier) {
        uint256 actualTokens = tokens;
        uint refund = 0;
        if (tokens > coinsRemaining) { //can't sell desired # tokens
            Reduction("in tier",recipient,tokens,coinsRemaining);
            actualTokens = coinsRemaining;
            refund = safeSub(tokens, coinsRemaining ); // refund amount in tokens
            refund = safeDiv(refund*1 ether,hgtRate );  // refund amount in ETH
            // need a refund mechanism here too
            coinsRemaining = 0;
            val = safeSub( val,refund);
        } else {
            coinsRemaining  = safeSub(coinsRemaining,  actualTokens);
        }
        purchasedCoins  = safeAdd(purchasedCoins, actualTokens);

        totalTokens = safeAdd(totalTokens,actualTokens);

        require (token.transferFrom(HGT_Reserve, recipient,totalTokens)) ;

        Purchase(recipient,tierNo,val,actualTokens); // event

        deposits[recipient] = safeAdd(deposits[recipient],val); // in case of refund - could pull off etherscan
        refund += maxRefund;
        if (refund > 0) {
            ethRaised = safeSub(ethRaised,refund);
            recipient.transfer(refund);
        }
        if (coinsRemaining <= (MaxCoinsR1 - minimumCap)){ // has passed success criteria
            if (!multiSig.send(this.balance)) {                // send funds to HGF
                log0("cannot forward funds to owner");
            }
        }
        coinsLeftInTier = safeSub(coinsLeftInTier,actualTokens);
        if ((coinsLeftInTier == 0) && (coinsRemaining != 0)) { // exact sell out of non final tier
            coinsLeftInTier = coinsPerTier;
            tierNo++;
            endDate = now + tranchePeriod;
        }
        return;
      }
      // check that coinsLeftInTier >= coinsRemaining

      uint256 coins2buy = min256(coinsLeftInTier , coinsRemaining); 

      endDate = safeAdd( now, tranchePeriod);
      // Have bumped levels - need to modify end date here
      purchasedCoins = safeAdd(purchasedCoins, coins2buy);  // give all coins remaining in this tier
      totalTokens    = safeAdd(totalTokens,coins2buy);
      coinsRemaining = safeSub(coinsRemaining,coins2buy);

      uint weiCoinsLeftInThisTier = safeMul(coins2buy,1 ether);
      uint costOfTheseCoins = safeDiv(weiCoinsLeftInThisTier, hgtRate);  // how much did that cost?

      Purchase(recipient, tierNo,costOfTheseCoins,coins2buy); // event

      deposits[recipient] = safeAdd(deposits[recipient],costOfTheseCoins);
      val    = safeSub(val,costOfTheseCoins);
      tierNo = tierNo + 1;
      coinsLeftInTier = coinsPerTier;
    } while ((val > 0) && funding());

    // escaped because we passed the end of the universe.....
    // so give them their tokens
    require (token.transferFrom(HGT_Reserve, recipient,totalTokens)) ;

    if ((val > 0) || (maxRefund > 0)){
        Reduction("finished crowdsale, returning ",recipient,value,totalTokens);
        // return the remainder !
        recipient.transfer(val+maxRefund); // if you can't return the balance, abort whole process
    }
    if (!multiSig.send(this.balance)) {
        ethRaised = safeSub(ethRaised,this.balance);
        log0("cannot send at tier jump");
    }
  }
  
  function allocatedTokens(address grantee, uint256 numTokens) onlyOwner {
    require (now < startDate) ;
    if (numTokens < coinsRemaining) {
        coinsRemaining = safeSub(coinsRemaining, numTokens);
       
    } else {
        numTokens = coinsRemaining;
        coinsRemaining = 0;
    }
    preallocCoins = safeAdd(preallocCoins,numTokens);
    require (token.transferFrom(HGT_Reserve,grantee,numTokens));
  }

  function withdraw() { // it failed. Come and get your ether.
      if (failed()) {
          if (deposits[msg.sender] > 0) {
              uint256 val = deposits[msg.sender];
              deposits[msg.sender] = 0;
              msg.sender.transfer(val);
          }
      }
  }

  function complete() onlyOwner {  // this should not have to be called. Extreme measures.
      if (success()) {
          uint256 val = this.balance;
          if (val > 0) {
            if (!multiSig.send(val)) {
                log0("cannot withdraw");
            } else {
                log0("funds withdrawn");
            }
          } else {
              log0("nothing to withdraw");
          }
      }
  }

}
