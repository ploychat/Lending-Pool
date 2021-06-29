pragma solidity ^0.8.0;
import "./ploychat_token.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract lendingpool_erc20 is ERC20 {
    
    constructor() ERC20 ("PoolToken", "POOL") public { }

    
    struct Lender{ //should be upper case like Lender
        address _addr;
        uint _earningrecieved;
        // uint _balance;
        uint _balanceinpool;
    }
    
    struct Borrower{
        address _addr;
        uint _healthfactor; //Health factor is score out of 10 
        // uint _balance;
        uint _borrowbalance;
        uint _promisingrepaydate;     
        uint _portionofborrowamount;

    }
    
    mapping(address => Lender) public lenders; 
    mapping(address => Borrower) public borrowers;
    
    //mapping loan amount
    
    
    // address payable public pooladdr;
    
    // uint _totalamountinpool;
    uint _totalborrowamount;
    uint _totalrepayinterest;
    
    
    //borrower list/ lender list
    address[] public LenderList;
    address[] public BorrowerList;
    
    
    // constructor(address _pooladdr) public {
    //     pool.pooladdr = _pooladdr
    // }
    // mapping(address => pool) public Pools
    // event PoolUpdate(address indexed _to, uint _amount);
    
    event Deposit(address _addr, uint _amountdeposit, uint timestamp);
    event Withdraw(address _addr, uint _amountwithdraw, uint timestamp);
    event EarningYield(address _addr,  uint _interestreceive, uint timestamp);
    event Borrow(address _addr,  uint _amountborrow, uint _amounttorepay, uint _promisingrepaydate, uint timestamp);
    event Repay(address _addr, uint _amountrepay, uint _promisingrepaydate, uint timestamp);
    
    function init(address addr, uint _initamount) public {
        _mint(addr, _initamount);
    }
    
    // function getBalanceLender() public view returns(uint256) {
    //     return lenders[msg.sender]._balance;
    // }
    
    // function getBalanceBorrower() public view returns(uint256) {
    //     return borrowers[msg.sender]._balance;
    // }
    
    //function beforeTransfer() **********
    
    function getHealthFactor() public view returns(uint256) {
        return borrowers[msg.sender]._healthfactor;
    }
    
    function getBorrowBalane() public view returns(uint256) {
        return borrowers[msg.sender]._borrowbalance;
    }
    
    
    function getBalanceInPool() public view returns(uint256) {
        return lenders[msg.sender]._balanceinpool;
    }
    
    function getTotalBorrowAmount() public view returns(uint256) {
        return _totalborrowamount;
    }
    function getTotalRepayInterest() public view returns(uint256) {
        return _totalrepayinterest;
    }
    
    function getPortionOfBorrowAmount() public view returns (uint) {return borrowers[msg.sender]._portionofborrowamount;}

    
    function getTotalPoolBalance() public view returns(uint256) {
        return balanceOf(address(this));
    }

    function deposit(uint _amount) public { 
        
        bool found=false;
        
        for (uint256 i = 0; i < (LenderList).length; i++) { //mapping will be more efficient as it requires less gas, no need to go thru all the list
            if (msg.sender == LenderList[i]) {
                // BorrowerList.push(_borroweraddr);
                // borrowers[_borroweraddr]._healthfactor = 10;
                found=true;
                break;
                
            }
            
        }
        
        if (found==false) {
            LenderList.push(msg.sender);
        }
        
        require(balanceOf(msg.sender) != 0, "No balance left");
        
        transfer(address(this),_amount);


        // emit PoolUpdate(msg.sender, _amount);
        
        emit Deposit(lenders[msg.sender]._addr, _amount, block.timestamp);
        
        //lenders[_lenderaddr]._balance -= _amount;
        
        lenders[msg.sender]._balanceinpool += _amount;

    }
    
    function withdraw(uint _amount) public {
        bool found = false;
        
        for (uint256 i = 0; i < (LenderList).length; i++) {
            if (msg.sender == LenderList[i]) {
                found = true;
                break;
            }
        }
        
        if (!found) {
            "Lender cant be found in pool";
        }

        require(lenders[msg.sender]._balanceinpool != 0, "No balance in pool");
        
        // emit poolupdate(msg.sender, _amount);
        
        transfer( msg.sender, _amount);
        
        emit Withdraw(lenders[msg.sender]._addr, _amount, block.timestamp);

        lenders[msg.sender]._balanceinpool -= _amount;
        // _totalamountinpool -= _amount;

    }
    
    function calculateEarning(address _lenderaddr) public view returns (uint){
        
        // logic ของ earning คือต้องคิดให้เกี่ยวข้องกับคนที่มา repay ด้วย if similar to aave kue ja dynamic depending on total liquidity in pool (total amount in pool มาคิดได้)
        // uint totalinterest = (_totalamountinpool-_totalborrowamount)/10; 

        // now lets only do interestrate=2
        
        // ที่ยืมได้ มีให้ยืม ปล่อยยืมไปแล้ว แล้วมา weight ให้เท่ากับinterest rate from totalsupply
        uint earning;
        uint earningToShare; //depend on liquidity

        
        //if amount
        // interest = (lenders[msg.sender]._balanceinpool*_interestrate)/100;
        
        
        // Earning Rate
        // If total amount in pool<(0.25% totalsupply) - > earningtoshare 75% totalrepayinterest
        // If total amount in pool>(0.75% totalsupply) - > earningtoshare 25% totalrepayinterest
        // Else 50%  > interest 5% totalrepayinterest

        if (balanceOf(address(this)) <= (totalSupply()*25)/100) {earningToShare = (_totalrepayinterest*75)/100;}
        else if (balanceOf(address(this)) >= (totalSupply()*75)/100) {earningToShare = (_totalrepayinterest*25)/100;}
        else {earningToShare = (_totalrepayinterest*50)/100;}
        
        earning = (lenders[_lenderaddr]._balanceinpool*earningToShare)/balanceOf(address(this));


        return earning;
    }
    
    function earningYield(address _lenderaddr) public { //from pool as message sender
        bool found=false;
        for (uint256 i = 0; i < (LenderList).length; i++) {
            if (_lenderaddr == LenderList[i]) {
                found = true;
                break;
            }
        }
        
        if (!found) {
            "Lender cant be found in LenderList"
        ;}
        
        uint earningReceive = calculateEarning(_lenderaddr);
        lenders[_lenderaddr]._balanceinpool += earningReceive;
        lenders[_lenderaddr]._earningrecieved += earningReceive;


        emit EarningYield(_lenderaddr, earningReceive, block.timestamp);

    } //rinsert pai nai function eun 
    
    function getTime (uint256 _repayinterval) public view returns(uint256 time){
        return block.timestamp +_repayinterval*1 days;
    }
    
    function borrow( uint _amount, uint _repayinterval) public {
        // คำนวนก่อนเลยว่า uint intervalที่เข้ามา+block.timestamp

        bool approve = true;
        uint _interestratemode;
        uint portionofborrowamount;


        bool found=false;
        
        for (uint256 i = 0; i < (BorrowerList).length; i++) {
            if (msg.sender == BorrowerList[i]) {
                found=true;
                break;
                
            }
            
        }
        
        if (found==false) {
            BorrowerList.push(msg.sender);
            borrowers[msg.sender]._healthfactor = 100;
        }
        
        
        require(borrowers[msg.sender]._healthfactor >25, "Not enough healthfactor");
        
        require(_repayinterval<30, "Change your repay period into less than 30 days");
        

        
        // cannot borrow more than 75% of balance in pool
        portionofborrowamount = (_amount*100/balanceOf(address(this)));
        
        require(portionofborrowamount<75, "cannot borrow more than 75% of balance in pool");
        
        if (borrowers[msg.sender]._borrowbalance != 0) {
            approve=false;}
            
        if (portionofborrowamount>75) {
            approve=false;
            if (portionofborrowamount>25) {
            if (borrowers[msg.sender]._healthfactor<80) approve=false;}
        }
    
        
        if (borrowers[msg.sender]._healthfactor < 100) {
            if (borrowers[msg.sender]._healthfactor < 80) {
                if (_repayinterval>14) //if score<80 should repay within 14 days
                {approve=false;}
                
            }
            else if (borrowers[msg.sender]._healthfactor < 50) {
                if (_repayinterval>7) //if score<50 should repay within 7 days
                {approve=false;}
        }}
        
        //health factor indicate interestratemode
        if (borrowers[msg.sender]._healthfactor >80) {
            _interestratemode = 10; //repay interest =10%
        } 
        
        else {
            _interestratemode = 20; //repay interest =20%
            
        }
        
        
    
        //dedeuct
        
        uint repayInterest = (_amount/_interestratemode);
        
        uint amounttorepay = _amount + repayInterest;
        
        _totalrepayinterest += repayInterest;
        
        // transfer from needs to be approved first
        // transferFrom(address(this), msg.sender, _amount);
        
        
        if (approve=true) {//ERC20.approve(address(this), _amount);
        
        borrowers[msg.sender]._healthfactor -= portionofborrowamount;
        borrowers[msg.sender]._portionofborrowamount = portionofborrowamount;

        
        _transfer(address(this), msg.sender, _amount);
        borrowers[msg.sender]._borrowbalance += amounttorepay;
        
        // _totalamountinpool -= _amount;
        

        borrowers[msg.sender]._promisingrepaydate = (block.timestamp)+ _repayinterval*1 days;
        
            // event Borrow(address indexed _from, uint _amountborrow, uint _amounttorepay, uint _promisingrepaydate, uint timestamp);
         _totalborrowamount +=amounttorepay;
        emit Borrow(msg.sender, _amount, amounttorepay, (block.timestamp)+ _repayinterval*1 days, block.timestamp);}
        

        }
    
    function getContractAddress() public view returns (address) {return address(this);}
    
    
    function recalculateHealthFactor(address _borroweraddr, uint _amount) public view returns (uint){
        uint healthfactor = borrowers[_borroweraddr]._healthfactor;
        uint portionofrepay = (_amount/borrowers[msg.sender]._borrowbalance)*100; //portion of repay from total that they borrow in %
        
        uint timescore;
        uint amountscore;
        
        //check repay amount 
        amountscore=portionofrepay/2; //weight 50% of total score
        
        //check timescore
        if (amountscore>=50) {if (borrowers[msg.sender]._promisingrepaydate >= block.timestamp) { //คืนเร็ว weigh 50% of score
                timescore=50;
            }
            
            else {if (block.timestamp - (borrowers[msg.sender]._promisingrepaydate) < 3 days) { // past due 
                timescore=25 ;
                }
                
                else if ((block.timestamp - (borrowers[msg.sender]._promisingrepaydate) < 7 days)) { // past due
                    timescore=0 ;
                    }
                    
                else { // past due
                    timescore = 0-(10*(block.timestamp - (borrowers[msg.sender]._promisingrepaydate))) ;
            }}}
        
        
        // repay full
        // if (portionofrepay>=100) { 
        //     healthfactor += borrowers[msg.sender]._portionofborrowamount/2 ; //weight 50% of score
        //     //check date
        //   if (borrowers[msg.sender]._promisingrepaydate > block.timestamp) { //คืนเร็ว weigh 50% of score
        //         healthfactor += borrowers[msg.sender]._portionofborrowamount/2;
        //     }
            
        //     else {if ((borrowers[msg.sender]._promisingrepaydate - block.timestamp) < 3 days) { // past due 
        //         healthfactor -= borrowers[msg.sender]._portionofborrowamount/4 ;
        //         }
                
        //         else if ((borrowers[msg.sender]._promisingrepaydate - block.timestamp) < 7 days) { // past due
        //             healthfactor -= borrowers[msg.sender]._portionofborrowamount/2 ;
        //             }
                    
        //         if ((borrowers[msg.sender]._promisingrepaydate - block.timestamp) < 3 days) { // past due
        //             healthfactor -= borrowers[msg.sender]._portionofborrowamount ;
        //     }}
        //     }
        
        // //repay only portion of it
        // else {
        //     if (portionofrepay > 50) {healthfactor += borrowers[msg.sender]._portionofborrowamount/4;} //25%
        // }
        uint totalscore=amountscore+timescore;
        healthfactor += (totalscore* borrowers[msg.sender]._portionofborrowamount)/100;
        return healthfactor;
    }
    
    function repay(uint _amount) public {
        //recalculate healthfactor
        borrowers[msg.sender]._healthfactor = recalculateHealthFactor(msg.sender, _amount);
        
        transfer(address(this), _amount);
        borrowers[msg.sender]._borrowbalance -= _amount;
        // _totalamountinpool += _amount;
        
        //    event Repay(address indexed _from, uint _amountrepay, uint _promisingrepaydate, uint timestamp);
        
        emit Repay(borrowers[msg.sender]._addr,_amount, borrowers[msg.sender]._promisingrepaydate, block.timestamp);

    }
}

