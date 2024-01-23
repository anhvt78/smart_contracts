// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Supplier is ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _counter; //counter seller
    mapping(address => uint256) private _sellerId;
    // mapping(uint256 => address) private _seller;

    mapping(address => uint256) internal _balance; //sellerId -> balance

    event eventSellerRegister(address seller, uint256 sellerId);

    function register() public nonReentrant {
        uint256 sellerId = _sellerId[msg.sender];
        require(sellerId == 0, "Registed");

        _counter.increment();
        uint256 newId = _counter.current();
        _sellerId[msg.sender] = newId;

        // _seller[newId] = msg.sender;

        emit eventSellerRegister(msg.sender, newId);
    }

    function getSellerId(address seller) public view returns (uint256) {
        return _sellerId[seller];
    }

    // function getAddrFromId(uint256 sellerId) public view returns (address) {
    //     return _seller[sellerId];
    // }

    function withdraw(uint256 value) public nonReentrant {
        require(value <= _balance[msg.sender], "Balance not enough");
        payable(msg.sender).transfer(value);
        _balance[msg.sender] -= value;
    }

    function deposite() public payable nonReentrant {
        require(msg.value > 0, "Please submit value");
        _balance[msg.sender] += msg.value;
    }

    function getBalance() public view returns (uint256) {
        return _balance[msg.sender];
    }
}
