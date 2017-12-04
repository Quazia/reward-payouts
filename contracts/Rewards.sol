pragma solidity ^0.4.17;

contract Rewards{


    string public name     = "Reward Token";
    string public symbol   = "RWD";
    uint8  public decimals = 18;
    uint public period = 0;
    uint public totalSupply = 0;
    uint[] public sumPayout;

    mapping (address => uint) public  balances;
    mapping (address => mapping (address => uint))  public  allowance;
    mapping(address => UserInfo) public  info;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdraw(address indexed src, uint wad);

    struct UserInfo {
        uint lastTransfer;
        uint summedRewards;
    }

    function Reward() public {
        sumPayout[period++] = 0;
    }

    function updateRewards(address user) public {
        uint weightedpayout = sumPayout[period] - sumPayout[period];
        uint share = (period - info[user].lastTransfer) * weightedpayout;
        info[user].summedRewards += share;
        info[user].lastTransfer = period;
    }

    function addReward(uint reward) public {
        sumPayout[period] = sumPayout[period++] + (reward / totalSupply);
    }


    function() public payable {
        deposit();
    }
    function deposit() public payable {
        balances[msg.sender] += msg.value;
        Deposit(msg.sender, msg.value);
    }

    function balanceOf(address addr) public view returns(uint){
        if(addr == 0xdead){
            return this.balance - totalSupply;
        }
        return balances[addr];
    }
    function withdraw(uint amt) public {
        require(balances[msg.sender] >= amt);
        balances[msg.sender] -= amt;
        msg.sender.transfer(amt);
        Withdraw(msg.sender, amt);
    }

    function totalSupply() public view returns (uint) {
        return totalSupply;
    }

    function approve(address spender, uint amt) public returns (bool) {
        allowance[msg.sender][spender] = amt;
        Approval(msg.sender, spender, amt);
        return true;
    }

    function transfer(address dst, uint amt) public returns (bool) {
        return transferFrom(msg.sender, dst, amt);
    }

    function transferFrom(address src, address dst, uint amt) 
        public 
        returns (bool) 
    {
        require(balances[src] >= amt);

        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= amt);
            allowance[src][msg.sender] -= amt;
        }

        updateRewards(src);
        updateRewards(dst);
        
        balances[src] -= amt;
        balances[dst] += amt;


        Transfer(src, dst, amt);

        return true;
    }
}