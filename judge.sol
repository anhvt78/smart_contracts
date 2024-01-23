// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ratting.sol";

contract Judge {
    uint256 private judgeTimeout = 604800;
    struct VoteInfo {
        uint256 goodVotedCounter;
        uint256 badVotedCounter;
    }

    struct JudgeInfo {
        address seller;
        address buyer;
        address[] voteForSeller;
        address[] voteForBuyer;
        uint256 judgeFee;
        uint256 endTime;
        uint256 purchaseId;
    }

    mapping(uint256 => JudgeInfo) internal judgeItems;

    mapping(address => mapping(uint256 => uint256)) private votedCounter; //address => judgeId => amount

    mapping(address => VoteInfo) private voteInfos;

    function _createJudge(
        address seller,
        address buyer,
        uint256 purcharseId,
        uint256 judgeFee
    ) internal {
        JudgeInfo memory judgeInfo;
        judgeInfo.seller = seller;
        judgeInfo.buyer = buyer;
        judgeInfo.judgeFee = judgeFee;
        judgeInfo.endTime = block.timestamp + judgeTimeout;
        judgeItems[purcharseId] = judgeInfo;
    }

    function judge(uint256 purchaseId, bool purchaseIsValid) public payable {
        require(votedCounter[msg.sender][purchaseId] == 0, "Voted");

        require(block.timestamp < judgeItems[purchaseId].endTime, "Finished");

        uint256 voteCount = voteInfos[msg.sender].goodVotedCounter +
            voteInfos[msg.sender].badVotedCounter;

        if (judgeItems[purchaseId].judgeFee > 0) {
            require(
                voteCount > 1000 &&
                    voteInfos[msg.sender].goodVotedCounter * 2 > voteCount,
                "Not allowed"
            );
            require(
                msg.value == (judgeItems[purchaseId].judgeFee / 10),
                "Please submit fee"
            );
        }

        if (purchaseIsValid) {
            judgeItems[purchaseId].voteForSeller.push(msg.sender);
        } else {
            judgeItems[purchaseId].voteForBuyer.push(msg.sender);
        }

        votedCounter[msg.sender][purchaseId] += 1;
    }

    function _finishJudge(uint256 purchaseId) internal returns (address) {
        require(
            block.timestamp > judgeItems[purchaseId].endTime,
            "In processing"
        );

        address winner;

        uint256 voteForSeller = judgeItems[purchaseId].voteForSeller.length;
        uint256 voteForBuyer = judgeItems[purchaseId].voteForBuyer.length;

        uint256 voteTotal = voteForSeller + voteForBuyer;

        if (voteTotal >= 3) {
            if (voteForSeller >= voteForBuyer) {
                //winner is complainant;
                winner = judgeItems[purchaseId].seller;
                uint256 profit = (judgeItems[purchaseId].judgeFee +
                    ((voteTotal * judgeItems[purchaseId].judgeFee) / 10)) /
                    (voteForSeller);

                _finishWithFee(
                    judgeItems[purchaseId].voteForSeller,
                    purchaseId,
                    profit
                );
                _finishWithoutFee(
                    judgeItems[purchaseId].voteForBuyer,
                    purchaseId
                );
            } else {
                //winner is defendant;
                winner = judgeItems[purchaseId].buyer;

                uint256 profit = (judgeItems[purchaseId].judgeFee *
                    ((voteTotal * judgeItems[purchaseId].judgeFee) / 10)) /
                    (voteForSeller);
                _finishWithFee(
                    judgeItems[purchaseId].voteForBuyer,
                    purchaseId,
                    profit
                );
                _finishWithoutFee(
                    judgeItems[purchaseId].voteForSeller,
                    purchaseId
                );
            }
        } else {
            winner = address(0);
            uint256 profit = judgeItems[purchaseId].judgeFee / 10;
            _finishWithFee(
                judgeItems[purchaseId].voteForBuyer,
                purchaseId,
                profit
            );
            _finishWithFee(
                judgeItems[purchaseId].voteForSeller,
                purchaseId,
                profit
            );
        }

        return winner;
    }

    function _finishWithFee(
        address[] memory addrs,
        uint256 purchaseId,
        uint256 profit
    ) private {
        for (uint256 i; i < addrs.length; i++) {
            payable(addrs[i]).transfer(profit); //return fee
            voteInfos[addrs[i]].goodVotedCounter += 1;
            delete votedCounter[addrs[i]][purchaseId];
        }
    }

    function _finishWithoutFee(
        address[] memory addrs,
        uint256 purchaseId
    ) private {
        for (uint256 i; i < addrs.length; i++) {
            voteInfos[addrs[i]].badVotedCounter += 1;
            delete votedCounter[addrs[i]][purchaseId];
        }
    }
}
