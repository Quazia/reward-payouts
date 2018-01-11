pragma solidity ^0.4.17;

/*
    Copyright 2016, Arthur Lunn

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/// @title Rewards Contract
/// @author Arthur Lunn
/// @dev This token is meant to allow for the easy distribution of tokens
///  to a group of token holders in all constant time operations. This
///  circumvents many of the issues present with the niave approach of simply
///  burning tokens to reward token holders in that it allows both time-specific
///  and variable payout rewards without the need to send to each individual
///  that is being rewarded.

import "./Controlled.sol";
import "./TokenController.sol";

contract Rewards{

    string public name     = "Reward Token";
    string public symbol   = "RWD";
    uint8  public decimals = 18;
    uint public period = 0;
    uint public totalSupply = 0;
    uint[] public sumPayout;
    bool public transfersEnabled = true;
    address public controller = 0x0;

    mapping (address => uint) public  balances;
    mapping (address => mapping (address => uint))  public  allowed;
    mapping(address => UserInfo) public  info;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdraw(address indexed src, uint wad);

    /// @dev this structure is used to store information
    ///  for an individual users payout.
    struct UserInfo {
        uint lastTransfer;
        uint summedRewards;
    }

    /// @dev `Reward` serves as a basic constructor and simply initializes
    ///  the total payouts for the first period to 0.
    function Reward() public {
        sumPayout[period++] = 0;
        controller = msg.sender;
    }

    /// @dev `updateRewards` is used to update the rewards for an individual
    ///  user at a specific time. This function should be called any time
    ///  that a users balance changes for any reason. 
    /// @param user This is the user to update given as an ethereum address.
    function updateRewards(address user) public {
        // If this user has already been updated on the current period
        // they don't need to be updated again.
        if(info[user].lastTransfer == period) return;
        // This gets the weighted payout for the period spanning from
        // the last transfer or change in balance the user had, to the current
        // period.
        uint weightedpayout = sumPayout[info[user].lastTransfer] - sumPayout[period];
        // Based on the weighted payout of the updated period, get the
        // share that user should have based on their balance for that period
        uint share = balances[user] * weightedpayout;
        // Update the user's info
        info[user].summedRewards += share;
        info[user].lastTransfer = period;
    }

    /// @dev `addRewards` allows for distribution of ether to all of
    ///  the users currently holding tokens. This function needs some sort
    ///  of permission based access control. Controller contract should work.
    function addReward() public payable{
        sumPayout[period] = sumPayout[period++] + (msg.value / totalSupply);
    }

    /// @dev The default fallback function just triggers the addReward function.
    function() public payable {
        addReward();
    }

    /// @dev This allows for the minting of reward tokens. This function
    ///  needs some sort of permission based access control. Controller
    ///  contract should work.
    function mint(address user, uint amount) public {
        balances[user] += amount;
        Deposit(user, amount);
    }

    /// @param _owner The address that's balance is being requested
    /// @return The balance of `addr` at the current block
    function balanceOf(address addr) public view returns(uint){
        if(addr == 0xdead){
            return this.balance - totalSupply;
        }
        return balances[addr];
    }

    /// @dev `withdraw` allows a user to withdraw their rewards in ether.
    /// @param amt the amount to withdraw
    function withdraw(uint amt) public {
        require(info[msg.sender].summedRewards >= amt);
        info[msg.sender].summedRewards -= amt;
        msg.sender.transfer(amt);
        Withdraw(msg.sender, amt);
    }

    /// @dev `totalSupply` is a basic helper function to get the current total
    ///  supply of reward tokens.
    /// @return The total supply of reward tokens.
    function totalSupply() public view returns (uint) {
        return totalSupply;
    }

    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on
    ///  its behalf. This is a modified version of the ERC20 approve function
    ///  to be a little bit safer
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _amount The amount of tokens to be approved for transfer
    /// @return True if the approval was successful
    function approve(address _spender, uint256 _amount) public returns (bool success) {
        require(transfersEnabled);

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender,0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require((_amount == 0) || (allowed[msg.sender][_spender] == 0));

        // Alerts the token controller of the approve function call
        if (isContract(controller)) {
            require(TokenController(controller).onApprove(msg.sender, _spender, _amount));
        }

        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }


    /// @notice Send `_amount` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        require(transfersEnabled);
        doTransfer(msg.sender, _to, _amount);
        return true;
    }

    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it
    ///  is approved by `_from`
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transferFrom(address _from, address _to, uint256 _amount
    ) public returns (bool success) {

        // The controller of this contract can move tokens around at will,
        //  this is important to recognize! Confirm that you trust the
        //  controller of this contract, which in most situations should be
        //  another open source smart contract or 0x0
        if (msg.sender != controller) {
            require(transfersEnabled);

            // The standard ERC 20 transferFrom functionality
            require(allowed[_from][msg.sender] >= _amount);
            allowed[_from][msg.sender] -= _amount;
        }
        doTransfer(_from, _to, _amount);
        return true;
    }

        /// @dev This is the actual transfer function in the token contract, it can
    ///  only be called by other functions in this contract.
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _amount The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function doTransfer(address _from, address _to, uint _amount
    ) internal {
           
           // If the amount is zero throw an event as dictated by the standard
           if (_amount == 0) {
               Transfer(_from, _to, _amount);    
               return;
           }

           // Do not allow transfer to 0x0 or the token contract itself
           require((_to != 0) && (_to != address(this)));

           // If the amount being transfered is more than the balance of the
           //  account the transfer throws
           var previousBalanceFrom = balanceOf(_from);

           require(previousBalanceFrom >= _amount);

           // Alerts the token controller of the transfer
           if (isContract(controller)) {
               require(TokenController(controller).onTransfer(_from, _to, _amount));
           }

           // First update the balance array with the new value for the address
           //  sending the tokens
           balances[_from] =  previousBalanceFrom - _amount;

           // Then update the balance array with the new value for the address
           //  receiving the tokens
           var previousBalanceTo = balanceOf(_to);
           require(previousBalanceTo + _amount >= previousBalanceTo); // Check for overflow
           balances[_to] =  previousBalanceTo + _amount;

           // Log an event to make the transfer easy to find on the blockchain
           Transfer(_from, _to, _amount);

    }

    /// @dev Internal function to determine if an address is a contract
    /// @param _addr The address being queried
    /// @return True if `_addr` is a contract
    function isContract(address _addr) constant internal returns(bool) {
        uint size;
        if (_addr == 0) return false;
        assembly {
            size := extcodesize(_addr)
        }
        return size>0;
    }

}