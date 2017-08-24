pragma solidity ^0.4.11;

import "./inc/Pausable.sol";
import "./inc/Ownable.sol";
import "./inc/SafeMath.sol";
import "./inc/ERC20.sol";
import "./GoldFees.sol";

contract GoldBackedToken is Ownable, SafeMath, ERC20, Pausable {

  event Transfer(address indexed from, address indexed to, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
  event DeductFees(address indexed owner,uint256 amount);

  event TokenMinted(address destination, uint256 amount);
  event TokenBurned(address source, uint256 amount);
  
	string public name = "HelloGold Gold Backed Token";
	string public symbol = "GBT";
	uint256 constant public  decimals = 18;  // same as ETH
	uint256 constant public  hgtDecimals = 8;
		
	uint256 constant public allocationPool = 1 *  10**9 * 10**hgtDecimals;      // total HGT holdings
	uint256	constant public	maxAllocation  = 38 * 10**5 * 10**decimals;			// max GBT that can ever ever be given out
	uint256	         public	totAllocation;			// amount of GBT so far
	
	address			 public feeCalculator;
	address		     public HGT;					// HGT contract address



	function setFeeCalculator(address newFC) onlyOwner {
		feeCalculator = newFC;
	}

	// GoldFees needs to take care of Domain Offset - do not do here

	function calcFees(uint256 from, uint256 to, uint256 amount) returns (uint256 val, uint256 fee) {
		return GoldFees(feeCalculator).calcFees(from,to,amount);
	}

	function GoldBackedToken(address feeCalc) {
		feeCalculator = feeCalc;
	}

    struct allocation { 
        uint256     amount;
        uint256     date;
    }
	
	allocation[]   public allocationsOverTime;
	allocation[]   public currentAllocations;

	function currentAllocationLength() constant returns (uint256) {
		return currentAllocations.length;
	}

	function aotLength() constant returns (uint256) {
		return allocationsOverTime.length;
	}

	
    struct Balance {
        uint256 amount;                 // amount through update or transfer
        uint256 lastUpdated;            // DATE last updated
        uint256 nextAllocationIndex;    // which allocationsOverTime record contains next update
        uint256 allocationShare;        // the share of allocationPool that this holder gets (means they hold HGT)
    }

	/*Creates an array with all balances*/
	mapping (address => Balance) public balances;
	mapping (address => mapping (address => uint)) allowed;
	
	function update(address where) internal {
        uint256 pos;
		uint256 fees;
		uint256 val;
        (val,fees,pos) = updatedBalance(where);
	    balances[where].nextAllocationIndex = pos;
	    balances[where].amount = val;
        balances[where].lastUpdated = now;
	}
	
	function updatedBalance(address where) constant public returns (uint val, uint fees, uint pos) {
		uint256 c_val;
		uint256 c_fees;
		uint256 c_amount;

		(val, fees) = calcFees(balances[where].lastUpdated,now,balances[where].amount);

	    pos = balances[where].nextAllocationIndex;
		if ((pos < currentAllocations.length) &&  (balances[where].allocationShare != 0)) {

			c_amount = currentAllocations[balances[where].nextAllocationIndex].amount * balances[where].allocationShare / allocationPool;

			(c_val,c_fees)   = calcFees(currentAllocations[balances[where].nextAllocationIndex].date,now,c_amount);

		} 

	    val  += c_val;
		fees += c_fees;
		pos   = currentAllocations.length;
	}

    function balanceOf(address where) constant returns (uint256 val) {
        uint256 fees;
		uint256 pos;
        (val,fees,pos) = updatedBalance(where);
        return ;
    }

	event Allocation(uint256 amount, uint256 date);
	event FeeOnAllocation(uint256 fees, uint256 date);

	event PartComplete();
	event StillToGo(uint numLeft);
	uint256 public partPos;
	uint256 public partFees;
	uint256 partL;
	allocation[]   public partAllocations;

	function partAllocationLength() constant returns (uint) {
		return partAllocations.length;
	}

	function addAllocationPartOne(uint newAllocation,uint numSteps) onlyOwner{
		uint256 thisAllocation = newAllocation;

		require(totAllocation < maxAllocation);		// cannot allocate more than this;

		if (currentAllocations.length > partAllocations.length) {
			partAllocations = currentAllocations;
		}

		if (totAllocation + thisAllocation > maxAllocation) {
			thisAllocation = maxAllocation - totAllocation;
			log0("max alloc reached");
		}
		totAllocation += thisAllocation;

		Allocation(thisAllocation,now);

        allocation memory newDiv;
        newDiv.amount = thisAllocation;
        newDiv.date = now;
		// store into history
	    allocationsOverTime.push(newDiv);
		// add this record to the end of currentAllocations
		partL = partAllocations.push(newDiv);
		// update all other records with calcs from last record
		if (partAllocations.length < 2) { // no fees to consider
			PartComplete();
			currentAllocations = partAllocations;
			FeeOnAllocation(0,now);
			return;
		}
		//
		// The only fees that need to be collected are the fees on location zero.
		// Since they are the last calculated = they come out with the break
		//
		for (partPos = partAllocations.length - 2; partPos >= 0; partPos-- ){
			(partAllocations[partPos].amount,partFees) = calcFees(partAllocations[partPos].date,now,partAllocations[partPos].amount);

			partAllocations[partPos].amount += partAllocations[partL - 1].amount;
			partAllocations[partPos].date    = now;
			if ((partPos == 0) || (partPos == partAllocations.length-numSteps)){
				break; 
			}
		}
		if (partPos != 0) {
			StillToGo(partPos);
			return; // not done yet
		}
		PartComplete();
		FeeOnAllocation(partFees,now);
		currentAllocations = partAllocations;
	}

	function addAllocationPartTwo(uint numSteps) onlyOwner {
		require(numSteps > 0);
		require(partPos > 0);
		for (uint i = 0; i < numSteps; i++ ){
			partPos--;
			(partAllocations[partPos].amount,partFees) = calcFees(partAllocations[partPos].date,now,partAllocations[partPos].amount);

			partAllocations[partPos].amount += partAllocations[partL - 1].amount;
			partAllocations[partPos].date    = now;
			if (partPos == 0) {
				break; 
			}
		}
		if (partPos != 0) {
			StillToGo(partPos);
			return; // not done yet
		}
		PartComplete();
		FeeOnAllocation(partFees,now);
		currentAllocations = partAllocations;
	}


	function setHGT(address _hgt) onlyOwner {
		HGT = _hgt;
	}

	function parentFees(address where) whenNotPaused {
		require(msg.sender == HGT);
	    update(where);		
	}
	
	function parentChange(address where, uint newValue) whenNotPaused { // called when HGT balance changes
		require(msg.sender == HGT);
	    balances[where].allocationShare = newValue;
	}
	
	/* send GBT */
	function transfer(address _to, uint256 _value) whenNotPaused returns (bool ok) {
	    update(msg.sender);              // Do this to ensure sender has enough funds.
		update(_to); 

        balances[msg.sender].amount = safeSub(balances[msg.sender].amount, _value);
        balances[_to].amount = safeAdd(balances[_to].amount, _value);

		Transfer(msg.sender, _to, _value); //Notify anyone listening that this transfer took place
        return true;
	}

	function transferFrom(address _from, address _to, uint _value) whenNotPaused returns (bool success) {
		var _allowance = allowed[_from][msg.sender];

	    update(_from);              // Do this to ensure sender has enough funds.
		update(_to); 

		balances[_to].amount = safeAdd(balances[_to].amount, _value);
		balances[_from].amount = safeSub(balances[_from].amount, _value);
		allowed[_from][msg.sender] = safeSub(_allowance, _value);
		Transfer(_from, _to, _value);
		return true;
	}

  	function approve(address _spender, uint _value) whenNotPaused returns (bool success) {
		require((_value == 0) || (allowed[msg.sender][_spender] == 0));
    	allowed[msg.sender][_spender] = _value;
    	Approval(msg.sender, _spender, _value);
    	return true;
  	}

  	function allowance(address _owner, address _spender) constant returns (uint remaining) {
    	return allowed[_owner][_spender];
  	}

	// Minting Functions 
	address public authorisedMinter;

	function setMinter(address minter) onlyOwner {
		authorisedMinter = minter;
	}
	
	function mintTokens(address destination, uint256 amount) {
		require(msg.sender == authorisedMinter);
		update(destination);
		balances[destination].amount = safeAdd(balances[destination].amount, amount);
		balances[destination].lastUpdated = now;
		balances[destination].nextAllocationIndex = currentAllocations.length;
		TokenMinted(destination,amount);
	}

	function burnTokens(address source, uint256 amount) {
		require(msg.sender == authorisedMinter);
		update(source);
		balances[source].amount = safeSub(balances[source].amount,amount);
		balances[source].lastUpdated = now;
		balances[source].nextAllocationIndex = currentAllocations.length;
		TokenBurned(source,amount);
	}

}