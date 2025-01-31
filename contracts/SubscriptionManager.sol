// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./lib/SafeMath.sol";

contract SubscriptionManager is Ownable{
    
    using SafeMath for *;

    uint256 public constant DURATION = 30 days;
    uint256 public subscriptionFee = 1000000000;  // 1 Gwei 

    mapping(address => uint256) public subscriptions;

    event SubscriptionPurchased(address indexed subscriber, uint256 expiryDate);
    event SubscriptionRenewed(address indexed subscriber, uint256 expiryDate);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    constructor() Ownable(msg.sender){
    }

    // setter function

    // Set subscriptionFee for the payment
    function setsubscriptionFee(uint256 _subscriptionFee) external onlyOwner {
        require(_subscriptionFee > 0, "INVALID_SUBSCRIPTION_FEE");
        subscriptionFee = _subscriptionFee;
    }

    function subscribe() external payable {
        require(msg.value == subscriptionFee, "Incorrect fee");
        require(subscriptions[msg.sender] < block.timestamp, "Subscription still active");

        uint256 expiry = block.timestamp.add(DURATION);
        subscriptions[msg.sender] = expiry;

        emit SubscriptionPurchased(msg.sender, expiry);
    }

    function renewSubscription() external payable {
        require(msg.value == subscriptionFee, "Incorrect fee");
        require(subscriptions[msg.sender] >= block.timestamp, "Subscription expired, subscribe again");

        subscriptions[msg.sender] = subscriptions[msg.sender].add(DURATION);
        
        emit SubscriptionRenewed(msg.sender, subscriptions[msg.sender]);
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(owner(), balance);
    }
}
