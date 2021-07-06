pragma solidity 0.8.4;
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Pool {
    event Deposit(address _addr, uint _amountdeposit, uint timestamp);
    event Withdraw(address _addr, uint _amountwithdraw, uint timestamp);
    event EarningYield(address _addr,  uint _interestreceive, uint timestamp);
    event Borrow(address _addr,  uint _amountborrow, uint _amounttorepay, uint _promisingrepaydate, uint timestamp);
    event Repay(address _addr, uint _amountrepay, uint _promisingrepaydate, uint timestamp);
    
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
    
    // uint _totalamountinpool;
    uint _totalborrowamount;
    uint _totalrepayinterest;
    //uint _totalsupplyincontract; //*****
    
    
    //borrower list/ lender list
    address[] public LenderList;
    address[] public BorrowerList;
    
    mapping(address => Lender) public lenders; 
    mapping(address => Borrower) public borrowers;
    mapping(address => uint256) public tokens; //****
    
    function getContractTotalSupply(address token) public view returns(uint256) {
        return tokens[token];
    } //how many tokens have been associated with the contract
    
    function getHealthFactor() public view returns(uint256) {
        return borrowers[msg.sender]._healthfactor;
    }
    
    function getBorrowBalance() public view returns(uint256) {
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

    
    function depositToken(address token, uint256 amount) public {
        
        bool found=false;
        
        for (uint256 i = 0; i < (LenderList).length; i++) { //mapping will be more efficient as it requires less gas, no need to go thru all the list
            if (msg.sender == LenderList[i]) {
                found=true;
                break;}
            
        }
        
        if (found==false) {
            LenderList.push(msg.sender);
        }
        
        require(IERC20(token).balanceOf(msg.sender) != 0, "No balance left");
        tokens[token]+=amount;
        IERC20(token).transferFrom(msg.sender, address(this), amount); //msg.sender = token holder / investor
        
        emit Deposit(msg.sender, amount, block.timestamp);
        
        lenders[msg.sender]._balanceinpool += amount;

    }
    
    function calculateEarning(address token, address _lenderaddr) public view returns (uint){
        uint earning;
        uint earningToShare; //depend on liquidity
        
        // Earning Rate
        // If total amount in pool<(0.25% totalsupply) - > earningtoshare 75% totalrepayinterest
        // If total amount in pool>(0.75% totalsupply) - > earningtoshare 25% totalrepayinterest
        // Else 50%  > interest 5% totalrepayinterest

        if (IERC20(token).balanceOf(address(this)) <= (getContractTotalSupply(token)*25)/100) {earningToShare = (_totalrepayinterest*75)/100;}
        else if (IERC20(token).balanceOf(address(this)) >= (getContractTotalSupply(token)*75)/100) {earningToShare = (_totalrepayinterest*25)/100;}
        else {earningToShare = (_totalrepayinterest*50)/100;}
        
        earning = (lenders[_lenderaddr]._balanceinpool*earningToShare)/IERC20(token).balanceOf(address(this));

        return earning;
    }
    
    function earningYield(address token, address _lenderaddr) public { //from pool as message sender
        bool found=false;
        for (uint256 i = 0; i < (LenderList).length; i++) {
            if (_lenderaddr == LenderList[i]) {
                found = true;
                break;
            }
        }
        require(found, "Lender cant be found in LenderList");
        
        uint earningReceive = calculateEarning(token, _lenderaddr);
        lenders[_lenderaddr]._balanceinpool += earningReceive;
        lenders[_lenderaddr]._earningrecieved += earningReceive;


        emit EarningYield(_lenderaddr, earningReceive, block.timestamp);

    }
    
    function withdrawToken(address token, uint256 amount) public {
        bool found = false;
        for (uint256 i = 0; i < (LenderList).length; i++) {
            if (msg.sender == LenderList[i]) {
                found = true;
                break;
            }
        }
        
        earningYield(token, msg.sender); //*****************
        
        require(found, "Lender cannot be found in pool");
        require(lenders[msg.sender]._balanceinpool != 0, "No balance in pool");
        
        
        tokens[token]-=amount;

        IERC20(token).transfer(msg.sender, amount);
        
        emit Withdraw(lenders[msg.sender]._addr, amount, block.timestamp);

        lenders[msg.sender]._balanceinpool -= amount;
        
    }
    
    function getTime (uint256 _repayinterval) public view returns(uint256 time){
        return block.timestamp +_repayinterval*1 days;
    }
    
    function approveBorrow(address token, address _borroweraddr, uint256 amount, uint256 interval) public returns(bool){
    bool approve = true;
        uint _interestratemode;
        uint portionofborrowamount;
        bool found=false;
        
        for (uint256 i = 0; i < (BorrowerList).length; i++) {
            if (_borroweraddr == BorrowerList[i]) {
                found=true;
                break;
                
            }
            
        }
        
        if (found==false) {
            BorrowerList.push(_borroweraddr);
            borrowers[_borroweraddr]._healthfactor = 100;
        }
        
        
        require(borrowers[_borroweraddr]._healthfactor >25, "Not enough healthfactor");
        
        require(interval<30, "Change your repay period into less than 30 days");
        

        
        // cannot borrow more than 75% of balance in pool
        portionofborrowamount = (amount*100/IERC20(token).balanceOf(address(this)));
        
        require(portionofborrowamount<75, "cannot borrow more than 75% of balance in pool");
        
        if (borrowers[_borroweraddr]._borrowbalance != 0) {
            approve=false;}
            
    
        if (portionofborrowamount>25) {
        if (borrowers[_borroweraddr]._healthfactor<80) approve=false;}
        
        
        if (borrowers[_borroweraddr]._healthfactor < 100) {
            if (borrowers[_borroweraddr]._healthfactor < 80) {
                if (interval>14) //if score<80 should repay within 14 days
                {approve=false;}
                
            }
            else if (borrowers[_borroweraddr]._healthfactor < 50) {
                if (interval>7) //if score<50 should repay within 7 days
                {approve=false;}
        }}
            
        
        return approve;
        
    }
    
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
      
        uint totalscore=amountscore+timescore;
        healthfactor += (totalscore* borrowers[msg.sender]._portionofborrowamount)/100;
        return healthfactor;
    }
    
    function borrowToken(address token, uint256 amount, uint256 interval) public {
        
        uint _interestratemode;
        uint portionofborrowamount;

        require(approveBorrow(token,msg.sender,amount,interval), "Not approve");
        
        //health factor indicate interestratemode
        if (borrowers[msg.sender]._healthfactor >80) {
            _interestratemode = 10; //repay interest =10%
        } 
        
        else {
            _interestratemode = 20; //repay interest =20%
            
        }
        
        portionofborrowamount = (amount*100/IERC20(token).balanceOf(address(this)));
    
        //dedeuct
        
        uint repayInterest = (amount/_interestratemode);
        uint amounttorepay = amount + repayInterest;
        _totalrepayinterest += repayInterest;
    
        
        borrowers[msg.sender]._healthfactor -= portionofborrowamount;
        borrowers[msg.sender]._portionofborrowamount = portionofborrowamount;
        borrowers[msg.sender]._borrowbalance += amounttorepay;
        borrowers[msg.sender]._promisingrepaydate = (block.timestamp)+interval*1 days;
        
            // event Borrow(address indexed _from, uint _amountborrow, uint _amounttorepay, uint _promisingrepaydate, uint timestamp);
         _totalborrowamount +=amounttorepay;
        emit Borrow(msg.sender, amount, amounttorepay, (block.timestamp)+interval*1 days, block.timestamp);
        IERC20(token).transferFrom(address(this), msg.sender, amount);
    }
    
    function repayToken(address token, uint256 amount) public {

        //recalculate healthfactor
        borrowers[msg.sender]._healthfactor = recalculateHealthFactor(msg.sender, amount);
        
        require(IERC20(token).balanceOf(msg.sender)>amount, "Not enough balanceo of token to repay ");
        IERC20(token).transfer(address(this), amount);
        borrowers[msg.sender]._borrowbalance -= amount;
        
        emit Repay(borrowers[msg.sender]._addr, amount, borrowers[msg.sender]._promisingrepaydate, block.timestamp);
    }
}
