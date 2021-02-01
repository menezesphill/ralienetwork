// SPDX-License-Identifier: MIT

/*
PermaVault is based on TokenVault https://gist.github.com/rstormsf/7cfb0c6b7a835c0c67b4a394b4fd9383

The PermaVault, different from a VestingVault, will lock a token ammount and release
the token to the treasury wallet during a period of time.

These tokens will be released daily during a timespam that starts at _vestingCliffInDays
and ends at _vestingDurationInDays

Once the token ammount is deposited to PermaVault, it can't be reverted. Not even by
the contract owner.

The tokens released daily is equal to (_amount)/(_vestingDurationInDays - _vestingCliffInDays)
*/

pragma solidity >=0.6.0 <0.8.0;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

contract PermaVault is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint16;

    struct Grant {
        uint256 startTime;
        uint256 amount;
        uint16 vestingDuration;
        uint16 daysClaimed;
        uint256 totalClaimed;
        address recipient;
    }

    event Deposit(address indexed recipient);
    event tokenReleased(address indexed recipient, uint256 amountClaimed);
    // event GrantRevoked(address recipient, uint256 amountVested, uint256 amountNotVested);

    ERC20 public token;
    
    mapping (address => Grant) private tokenGrants;

    constructor(ERC20 _token) {
        require(address(_token) != address(0));
        token = _token;
    }
    
    function addTokentoVault(
        address _recipient,
        uint256 _amount,
        uint16 _vestingDurationInDays,
        uint16 _vestingCliffInDays    
    ) 
        external
        onlyOwner
    {
        require(tokenGrants[_recipient].amount == 0, "Tokens already added to PermaVault.");
        require(_vestingCliffInDays <= 10*365, "Cliff greater than 10 years");
        require(_vestingDurationInDays <= 25*365, "Duration greater than 25 years");
        
        uint256 amountReleasedPerDay = _amount.div(_vestingDurationInDays);
        require(amountReleasedPerDay > 0, "amountReleasedPerDay > 0");

        // Transfer the grant tokens under the control of the vesting contract
        require(token.transferFrom(owner(), address(this), _amount));

        Grant memory grant = Grant({
            startTime: currentTime() + _vestingCliffInDays * 1 days,
            amount: _amount,
            vestingDuration: _vestingDurationInDays,
            daysClaimed: 0,
            totalClaimed: 0,
            recipient: _recipient
        });
        tokenGrants[_recipient] = grant;
        emit Deposit(_recipient);
    }

    /// @notice Allows a grant recipient to claim their vested tokens. Errors if no tokens have vested
    function releaseUnlockedTokens() external {
        uint16 daysVested;
        uint256 amountVested;
        (daysVested, amountVested) = calculateRelease(msg.sender);
        require(amountVested > 0, "0 Tokens to release");

        Grant storage tokenGrant = tokenGrants[msg.sender];
        tokenGrant.daysClaimed = uint16(tokenGrant.daysClaimed.add(daysVested));
        tokenGrant.totalClaimed = uint256(tokenGrant.totalClaimed.add(amountVested));
        
        require(token.transfer(tokenGrant.recipient, amountVested), "no tokens");
        emit tokenReleased(tokenGrant.recipient, amountVested);
    }

    /// @notice Terminate token grant transferring all vested tokens to the `_recipient`
    /// and returning all non-vested tokens to the contract owner
    /// Secured to the contract owner only
    /// @param _recipient address of the token grant recipient
    /*function revokeTokenGrant(address _recipient) 
        external 
        onlyOwner
    {
        Grant storage tokenGrant = tokenGrants[_recipient];
        uint16 daysVested;
        uint256 amountVested;
        (daysVested, amountVested) = calculateRelease(_recipient);

        uint256 amountNotVested = (tokenGrant.amount.sub(tokenGrant.totalClaimed)).sub(amountVested);

        require(token.transfer(owner(), amountNotVested));
        require(token.transfer(_recipient, amountVested));

        tokenGrant.startTime = 0;
        tokenGrant.amount = 0;
        tokenGrant.vestingDuration = 0;
        tokenGrant.daysClaimed = 0;
        tokenGrant.totalClaimed = 0;
        tokenGrant.recipient = address(0);

        emit GrantRevoked(_recipient, amountVested, amountNotVested);
    }*/

    function getReleaseStartTime(address _recipient) private view returns(uint256) {
        Grant storage tokenGrant = tokenGrants[_recipient];
        return tokenGrant.startTime;
    }

    function getReleaseAmount(address _recipient) public view returns(uint256) {
        Grant storage tokenGrant = tokenGrants[_recipient];
        return tokenGrant.amount;
    }

    /// @notice Calculate the vested and unclaimed months and tokens available for `_grantId` to claim
    /// Due to rounding errors once grant duration is reached, returns the entire left grant amount
    /// Returns (0, 0) if cliff has not been reached
    function calculateRelease(address _recipient) public view returns (uint16, uint256) {
        Grant storage tokenGrant = tokenGrants[_recipient];

        require(tokenGrant.totalClaimed < tokenGrant.amount, "Tokens fully released");

        // For grants created with a future start date, that hasn't been reached, return 0, 0
        if (currentTime() < tokenGrant.startTime) {
            return (0, 0);
        }

        // Check cliff was reached
        uint elapsedDays = currentTime().sub(tokenGrant.startTime - 1 days).div(1 days);

        // If over vesting duration, all tokens vested
        if (elapsedDays >= tokenGrant.vestingDuration) {
            uint256 remainingGrant = tokenGrant.amount.sub(tokenGrant.totalClaimed);
            return (tokenGrant.vestingDuration, remainingGrant);
        } else {
            uint16 daysVested = uint16(elapsedDays.sub(tokenGrant.daysClaimed));
            uint256 amountReleasedPerDay = tokenGrant.amount.div(uint256(tokenGrant.vestingDuration));
            uint256 amountVested = uint256(daysVested.mul(amountReleasedPerDay));
            return (daysVested, amountVested);
        }
    }

    function currentTime() private view returns(uint256) {
        return block.timestamp;
    }
}