// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./product.sol";
import "./judge.sol";
import "./supplier.sol";

contract SupperMarketplace is Supplier, Judge, Product {
    address private marketOwner;

    constructor() {
        marketOwner = msg.sender;
    }

    using SafeMath for uint256;
    using Counters for Counters.Counter;

    struct PurchaseItem {
        uint256 prodId;
        uint256 amount;
    }

    struct PurchaseInfo {
        address buyer;
        address seller;
        PurchaseItem[] orderDetail;
        uint256 totalPrice;
        uint256 saleConfirmedTime;
        string shippingInfoURI;
        uint256 shippingFee;
        uint256 shippingTimeOut;
        uint256 insurance;
        uint256 state;
        uint256 guaranteeType;
        /* state
         *0: Buyer create a cart
         *1: Buyer cancel
         *2: Sale confirmed
         *3: Sale cancel
         *4: Buyer refuse
         *5: Buyer confirm received
         *6: In judgement
         *7: judge is cancel
         *8: judge is finished
         *9: delivery confirmed
         */
    }

    uint256 shippingTimeout = 2629743; //1 month

    mapping(uint256 => PurchaseInfo) private purchaseItems; //purchaseId -> purchase Info

    Counters.Counter private purchaseCounter;

    struct RateInfo {
        uint256 rate;
        uint256 counter;
    }

    mapping(address => RateInfo) private rateInfo;

    mapping(address => uint256) private complainCounter; //khởi kiện

    event eventItemPurchase(address indexed buyer, uint256 purchaseId);

    function createPurchase(
        address seller,
        PurchaseItem[] memory items,
        uint256 shippingTime,
        uint256 shippingFee,
        uint256 guaranteeType //0: not use, 1: market, 2: community
    ) external payable nonReentrant {
        uint256 totalPrice;
        uint256 sellerId = getSellerId(seller);
        uint256 insurance;

        for (uint256 i; i <= items.length; i++) {
            require(
                product[sellerId][items[i].prodId].amount >= items[i].amount,
                "Not enough supply"
            );
            totalPrice += product[sellerId][items[i].prodId].price.mul(
                items[i].amount
            );
            insurance =
                (totalPrice * product[sellerId][items[i].prodId].insurance) /
                100;
        }

        uint256 value = totalPrice + shippingFee + insurance;

        require(msg.value == value, "Insufficient funds");

        purchaseCounter.increment();
        uint256 _purchaseId = purchaseCounter.current();

        // purchaseIdToIndex[_purchaseId] = purchaseActiveCount;
        // purchaseIndexToId[purchaseActiveCount] = _purchaseId;

        // purchaseActiveCount += 1;

        purchaseItems[_purchaseId].buyer = msg.sender;
        purchaseItems[_purchaseId].seller = seller;
        purchaseItems[_purchaseId].totalPrice = totalPrice;
        purchaseItems[_purchaseId].insurance = insurance;
        purchaseItems[_purchaseId].state = 0;
        purchaseItems[_purchaseId].guaranteeType = guaranteeType;

        purchaseItems[_purchaseId].shippingTimeOut =
            shippingTime +
            shippingTimeout;
        purchaseItems[_purchaseId].shippingFee = shippingFee;

        for (uint256 i; i <= items.length; i++) {
            purchaseItems[_purchaseId].orderDetail.push(items[i]);
        }

        emit eventItemPurchase(msg.sender, _purchaseId);
    }

    event eventCancelPurchase(uint256 purchaseId);

    function cancelPurchase(uint256 purchaseId) public payable nonReentrant {
        require(purchaseItems[purchaseId].buyer == msg.sender, "Only buyer");
        require(purchaseItems[purchaseId].state == 0, "Purchase is ready");

        uint256 returnFee = purchaseItems[purchaseId].totalPrice +
            purchaseItems[purchaseId].shippingFee +
            purchaseItems[purchaseId].insurance;

        payable(purchaseItems[purchaseId].buyer).transfer(returnFee);

        purchaseItems[purchaseId].state = 1;

        emit eventCancelPurchase(purchaseId);
    }

    event eventConfirmPurchase(uint256 purchaseId);

    function confirmPurchase(
        uint256 purchaseId,
        string memory shippingInfoURI
    ) public nonReentrant {
        require(purchaseItems[purchaseId].seller == msg.sender, "Only Seller");
        require(purchaseItems[purchaseId].state == 0, "Purchase invalid");
        require(
            _balance[purchaseItems[purchaseId].seller] >=
                purchaseItems[purchaseId].insurance,
            "Balance not enough for insurance"
        );
        _balance[purchaseItems[purchaseId].seller] -= purchaseItems[purchaseId]
            .insurance;
        purchaseItems[purchaseId].state = 2;
        purchaseItems[purchaseId].saleConfirmedTime = block.timestamp;
        purchaseItems[purchaseId].shippingInfoURI = shippingInfoURI;

        emit eventConfirmPurchase(purchaseId);
    }

    event eventConfirmReceived(uint256 purchaseId);

    function confirmReceived(uint256 purchaseId) public nonReentrant {
        require(purchaseItems[purchaseId].buyer == msg.sender, "Only buyer");
        require(purchaseItems[purchaseId].state == 2, "Invalid");
        purchaseItems[purchaseId].state = 5;

        _balance[purchaseItems[purchaseId].seller] =
            purchaseItems[purchaseId].totalPrice +
            purchaseItems[purchaseId].shippingFee +
            purchaseItems[purchaseId].insurance;
        payable(purchaseItems[purchaseId].buyer).transfer(
            purchaseItems[purchaseId].insurance
        );
        ratePermit[purchaseItems[purchaseId].buyer][
            purchaseItems[purchaseId].seller
        ] = true;

        // purchaseTimes[purchaseItems[purchaseId].buyer] += 1;

        emit eventConfirmReceived(purchaseId);
    }

    function confirmDelivery(uint256 purchaseId) public onlyMarketOwner {
        require(purchaseItems[purchaseId].guaranteeType == 1, "Not allow");
        require(purchaseItems[purchaseId].state == 2, "Invalid");
        purchaseItems[purchaseId].state = 9;

        _balance[purchaseItems[purchaseId].seller] =
            purchaseItems[purchaseId].totalPrice +
            purchaseItems[purchaseId].shippingFee +
            purchaseItems[purchaseId].insurance;
        payable(purchaseItems[purchaseId].buyer).transfer(
            purchaseItems[purchaseId].insurance
        );
        ratePermit[purchaseItems[purchaseId].buyer][
            purchaseItems[purchaseId].seller
        ] = true;

        // purchaseTimes[purchaseItems[purchaseId].buyer] += 1;

        emit eventConfirmReceived(purchaseId);
    }

    function getPurchasedItemInfo(
        uint256 purchaseId
    ) public view returns (PurchaseInfo memory) {
        return purchaseItems[purchaseId];
    }

    event eventCancelSale(uint256 purchaseId);

    function cancelSale(uint256 purchaseId) public payable nonReentrant {
        require(msg.sender == purchaseItems[purchaseId].seller, "Only Seller");

        // uint256 purchaseIndex = purchaseIdToIndex[purchaseId];
        // require(purchaseId == purchaseIndexToId[purchaseIndex], "Done");

        payable(purchaseItems[purchaseId].buyer).transfer(
            purchaseItems[purchaseId].totalPrice +
                purchaseItems[purchaseId].shippingFee +
                2 *
                purchaseItems[purchaseId].insurance
        );

        purchaseItems[purchaseId].state = 3;

        // _removePurchaseItem(purchaseId);

        //Thêm muc đánh giá của người dùng đối với người bán
        ratePermit[purchaseItems[purchaseId].buyer][
            purchaseItems[purchaseId].seller
        ] = true;

        emit eventCancelSale(purchaseId);
    }

    function rejectPurchase(uint256 purchaseId) public {
        require(msg.sender == purchaseItems[purchaseId].buyer, "Only buyer");
        require(purchaseItems[purchaseId].state == 2, "Not available");

        _balance[purchaseItems[purchaseId].seller] =
            purchaseItems[purchaseId].shippingFee +
            2 *
            purchaseItems[purchaseId].insurance;
        payable(purchaseItems[purchaseId].buyer).transfer(
            purchaseItems[purchaseId].totalPrice
        );

        purchaseItems[purchaseId].state = 4;
        // _removePurchaseItem(purchaseId);
    }

    function createJudge(uint256 purchaseId) public {
        uint256 timeOut = purchaseItems[purchaseId].saleConfirmedTime +
            purchaseItems[purchaseId].shippingTimeOut;
        require(block.timestamp > timeOut, "In shipping time");

        require(
            purchaseItems[purchaseId].state == 7 ||
                purchaseItems[purchaseId].state == 2,
            "Not available"
        );

        require(purchaseItems[purchaseId].guaranteeType == 2, "Not valid");

        uint256 judgeFee = purchaseItems[purchaseId].insurance;

        require(
            msg.sender == purchaseItems[purchaseId].seller ||
                msg.sender == purchaseItems[purchaseId].buyer,
            "Only entity of purchase"
        );

        _createJudge(
            purchaseItems[purchaseId].seller,
            purchaseItems[purchaseId].buyer,
            purchaseId,
            judgeFee
        );
        purchaseItems[purchaseId].state = 6;

        complainCounter[purchaseItems[purchaseId].buyer] += 1;
    }

    function finishJudge(uint256 purchaseId) public {
        address winner = _finishJudge(purchaseId);
        if (winner != address(0)) {
            purchaseItems[purchaseId].state = 8;

            payable(winner).transfer(
                purchaseItems[purchaseId].totalPrice +
                    purchaseItems[purchaseId].shippingFee +
                    purchaseItems[purchaseId].insurance
            );
        } else {
            purchaseItems[purchaseId].state = 7;
        }

        // _removePurchaseItem(purchaseId);
    }

    mapping(address => mapping(address => bool)) private ratePermit; //buyer => seller => purchaseId

    function getComplainTotal(address addr) public view returns (uint256) {
        return complainCounter[addr];
    }

    function rate(uint256 purchaseId, uint256 point) public {
        require(
            ratePermit[msg.sender][purchaseItems[purchaseId].seller],
            "Not allowed"
        );

        rateInfo[purchaseItems[purchaseId].seller].rate =
            (rateInfo[purchaseItems[purchaseId].seller].rate *
                rateInfo[purchaseItems[purchaseId].seller].counter +
                point) /
            (rateInfo[purchaseItems[purchaseId].seller].counter + 1);

        rateInfo[purchaseItems[purchaseId].seller].counter += 1;
        ratePermit[purchaseItems[purchaseId].buyer][
            purchaseItems[purchaseId].seller
        ] = false;
    }

    function getRate(address addr) public view returns (uint256) {
        return rateInfo[addr].rate;
    }

    function getRateCount(address addr) public view returns (uint256) {
        return rateInfo[addr].counter;
    }

    modifier onlyMarketOwner() {
        require(msg.sender == marketOwner, "Only market owner");
        _;
    }
}
