// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./supplier.sol";

contract Product is Supplier {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    struct ProdInfo {
        uint256 amount;
        uint256 price;
        string uri;
        uint256 insurance;
    }

    mapping(uint256 => uint256) private _prodCounter;

    mapping(uint256 => mapping(uint256 => ProdInfo)) internal product;

    event eventCreateProdItem(uint256 sellerId, uint256 prodId);

    function createProd(
        uint256 amount,
        uint256 price,
        string memory uri,
        uint256 insurance
    ) public {
        uint256 sellerId = getSellerId(msg.sender);
        require(sellerId != 0, "Only seller");
        uint256 newIndex = _prodCounter[sellerId];
        _prodCounter[sellerId] += 1;
        product[sellerId][newIndex] = ProdInfo(amount, price, uri, insurance);

        emit eventCreateProdItem(sellerId, newIndex);
    }

    function getTotalProd(uint256 sellerId) public view returns (uint256) {
        return _prodCounter[sellerId];
    }

    function getProdInfo(
        uint256 sellerId,
        uint256 prodIndex
    ) public view returns (ProdInfo memory) {
        // require(prodIndex < _prodCounter[sellerId], "Index out of limit");
        return product[sellerId][prodIndex];
    }

    event eventUpdateProdInfo(uint256 sellerId, uint256 prodIndex);

    function updateProdInfo(
        uint256 prodIndex,
        uint256 amount,
        uint256 price,
        uint256 insurance
    ) public {
        uint256 sellerId = getSellerId(msg.sender);
        require(sellerId != 0, "Only seller");
        require(
            prodIndex < _prodCounter[sellerId],
            "Product index out of limit"
        );

        product[sellerId][prodIndex].amount = amount;
        product[sellerId][prodIndex].price = price;
        product[sellerId][prodIndex].insurance = insurance;

        emit eventUpdateProdInfo(sellerId, prodIndex);
    }

    function removeProd(uint256 prodIndex) public {
        uint256 sellerId = getSellerId(msg.sender);
        require(sellerId != 0, "Only seller");
        require(
            prodIndex < _prodCounter[sellerId],
            "Product index out of limit"
        );
        _prodCounter[sellerId] -= 1;
        uint256 lastIndex = _prodCounter[sellerId];
        if (prodIndex != lastIndex) {
            product[sellerId][prodIndex] = product[sellerId][lastIndex];
        }

        delete product[sellerId][lastIndex];
    }
}
