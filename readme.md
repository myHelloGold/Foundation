Crowdsale Notes
===============

* Collects ether and allocates HGT
* Allocation is immediate
* sale aims to raise 2.1m USD by selling 80,000,000 HGT
* prices are set before the public sale to reflect the changing price of ether at that point
* allocation mechanism is via 'approve/transferFrom' in HGT
* HGT is frozen after initial approve until sale complete / confirmation of results (release of HGT)
* maximum personal contribution of 10 ether during public sale
* crowdsale based on block times.



------------
KYC

* depositors must have passed KYC
* KYC will be committed by Customer Service dept
* KYC states (a) KYC not passed, (b) KYC passed, (b) KYC passed but disable
* deposits only accepted for (b) KYC passed

------------
Tiers

* public sale is in price tiers of 16M HGT (max 5 tiers) individually priced
* price per tier set prior to sale start but after contract launch
* deposits accorded HGT proportional to the price of the current tier
* if a deposit completes one tier, the price of the HGT allocated will pro-rated
* Crowdsale has a start date. End date is set to 1 week after start.
* Each time a tranche is complete the new price comes into effect and the sale is extended to a week after that time until either last tranche is complete or total cap reached
* Final contribution will have any balance ether returned after paying for tokens up to the cap

--------
Link to HGT

* HGF links the HGT using the address set by the linkCoin() function

----------
Before and After

* Contributions received either before or after the sale will be rejected


HGT Notes
=========

* HGT is an ERC20 compliant token
* HGT will be launched with a value of 1,000,000,000 HGT in the HGF_Reserve account
* GBT address is set via the SetGBT() function
* Any transfer of HGT will cause a call to the GBT contract. 

-----
Calls to GBT

* prior to any transfer, GBT is notified for both sending and receiving addresses to allow fees to be calculated
* after any transfer the allocation shares of the  sending and receiving addresses are updated

N.B. The share of anybody's HGT determines the share of GBT rewards they will receive when they are distributed.


GBT Notes
=========

Creation of GBT by two means

* ALLOCATION - HGF allocate GBT which are shared among HGT holders pro-rata to their HGT holdings
* MINTING - HGF Mint GBT to back new gold allocation from HG

---

Destruction of GBT by two means

* Fees. Accounts are chrged fees on their GBT holding at 2% per annum calculated daily
* Conversion. GBT may be converted to gold in a HG account

---

Gold Fees

* Gold fees are calculated by an external contract to allow the ability to have more versatile fee structures in future

---

Balances

* GBT Balances will ususally be _calculated_ balances but are to be treated as _actual_
* Balances are calculated taking into account _fees_ and _allocations due_
* Balances are updated when the function parentFees() is called
* GBT records of the HGT allocaton share is updated by parentChange()

----
Allocation

HGF will periodically issue GBT rewards to be distributed equally to HGT holders.

GBT are subject to demurrage or fees currently rated at 2% per annum on a daily compound basis.

Each release goes into a record in an array which is available for history

```
    struct allocation { 
        uint256         amount;
        uint256         date;
    }
```

Allocations are stored in TWO arrays

* `allocationsOverTime` is an array of allocations as made and is for historical use only
* `currentAllocations` is an array of cumulative balances minus accumulated fees

On each new allocation (n), records 0..n-1 are updated by 

* deducting fees accrued since previous update
* adding the latest allocation
* updating the date

* NOTE - as you get past about the 160th allocation you will run out of gas. This is estimated to be in about 15 years.
  Assuming that we have not replaced the whole thing AND we are still allocation rewards.

* Introduced addAllocationPartOne and Part Two to handle that. Call addAllocationPartOne and if PartComplete not emitted keep calling addAllocationPartTwo repeatedly until it is 
  
GBT Account records
-------

GBT holds, per GBT or HGT holder:

```
    struct Balance {
        uint256 amount;                 // amount through update or transfer
        uint256 lastUpdated;            // DATE last updated
        uint256 nextAllocationIndex;    // which currentAllocations record to update with
        uint256 allocationShare;        // user's HGT share of allocationPool
    }
```

-----
Fee calculation


`calcFees(uint256 from, uint256 to, uint256 startAmount) returns (uint256 amount, uint256 fee)`

A Balance attracts fees of calcFees(lastUpdated,now,amount) at any time. These are burnt.

calcFees is a plugin contract so that it can be updated as we manage to reduce the fees or or improve the fee structure.

Minting
=======

Minting will be carried out when 

* HelloGold users convert their balances to GBT
* HelloGold issues Gold to HGF for sale

In each case authorisation will be from HelloGold and use the HelloGold MultiSig wallet.

Since each case involves a transfer of gold to HGF, there should be no impact on the price of GBT.

-----
Launch implementation steps
====

Launch contracts in this order : "HelloGoldToken", "GoldFees", "GoldBackedToken"


HGT launch params

* HGF_Reserve (HelloGold Foundation Reserve account)

HG Sale launch params

* HGT contract address
* Customer Service Wallet Address
* multi sig wallet address
* HGF Reserve address (to transfer from)

GoldFees launch params

* none

GBT launch params

* fee contract address

Post Launch setup

* Set GBT address in HGT contract
* Set HGT address in GBT contract
* Pause HGT

N.B. Transaction sent from HF_Reserve account (needs gas) to HGT contract


Launch "HelloGoldSale"
----------------------

Check the Params

* MaxCoins
* CoinsReminingR1
* CoinsPerTier
* CoinsLeftInTier
* MinimumCap

* launch contract
* Set Prices => 5 amounts of HGT/ETH + personal Max (in ether)
* Unpause HGT
* Set Allowance in HGT to allow crowdsale to disburse up to 300M tokens
`hellogoldtoken.Approve(role("HGF_Reserve"), saleAddress, t300M)`
* Pause HGT

Post Sale
---------

* Unpause HGT


