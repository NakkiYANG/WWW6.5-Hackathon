// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./InternSBT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ReviewContract is Ownable {

    // ── 枚举 ──────────────────────────────────────────
    enum ReviewStatus { Normal, Disputed, Revoked }

    // ── 数据结构 ──────────────────────────────────────
    struct Review {
        bytes32 credentialId;
        bytes32 cid;
        uint8   overallScore;
        ReviewStatus status;
        uint32  createdAt;
    }

    // ── 聚合统计（存总分，读时再除）────────────────────
    struct TargetStats {
        uint128 totalScore;    // 原始总分（*100）
        uint128 reviewCount;
    }

    // ── 状态变量 ──────────────────────────────────────
    InternSBT public sbtContract;

    mapping(bytes32 => Review[]) public targetReviews;
    mapping(address => mapping(bytes32 => bool)) public hasReviewed;
    mapping(bytes32 => TargetStats) public targetStats;

    // ── 事件 ──────────────────────────────────────────
    event ReviewSubmitted(
        bytes32 indexed targetId,
        address indexed reviewer,
        bytes32 credentialId,
        uint8   overallScore,
        bytes32 cid,
        uint256 createdAt
    );

    event ReviewStatusUpdated(
        bytes32 indexed targetId,
        uint256 indexed reviewIndex,
        ReviewStatus oldStatus,   // 方便链下索引
        ReviewStatus newStatus
    );

    // ── 构造函数 ──────────────────────────────────────
    constructor(address _sbtContract) Ownable(msg.sender) {
        sbtContract = InternSBT(_sbtContract);
    }

    // ── 核心函数：提交评价 ────────────────────────────
    function submitReview(
        bytes32 _targetId,
        uint8   _overallScore,
        bytes32 _cid
    ) external {
        // 1. 必须持有 SBT
        require(sbtContract.hasSBT(msg.sender), "No valid credential");

        // 2. 从链上读取 credentialId，不接受外部传入
        bytes32 credentialId = sbtContract.getCredentialId(msg.sender);

        // 3. 对同一个 target 只能评价一次
        require(!hasReviewed[msg.sender][_targetId], "Already reviewed this target");

        // 4. 总分必须在 1-5 之间
        require(
            _overallScore >= 1 && _overallScore <= 5,
            "Score must be between 1 and 5"
        );

        // 5. 存储评价
        targetReviews[_targetId].push(Review({
            credentialId: credentialId,
            cid: _cid,
            overallScore: _overallScore,
            status: ReviewStatus.Normal,
            createdAt: uint32(block.timestamp)
        }));

        // 6. 更新状态
        hasReviewed[msg.sender][_targetId] = true;
        _incrementScore(_targetId, _overallScore);

        emit ReviewSubmitted(
            _targetId, msg.sender, credentialId,
            _overallScore, _cid, block.timestamp
        );
    }

    // ── 申诉函数：只有 owner 可以操作 ─────────────────
    function updateReviewStatus(
        bytes32 _targetId,
        uint256 _reviewIndex,
        ReviewStatus _newStatus
    ) external onlyOwner {
        require(
            _reviewIndex < targetReviews[_targetId].length,
            "Review does not exist"
        );

        Review storage r = targetReviews[_targetId][_reviewIndex];
        ReviewStatus oldStatus = r.status;

        if (oldStatus == _newStatus) return;

        r.status = _newStatus;

        if (oldStatus == ReviewStatus.Normal && _newStatus != ReviewStatus.Normal) {
            _decrementScore(_targetId, r.overallScore);
        } else if (oldStatus != ReviewStatus.Normal && _newStatus == ReviewStatus.Normal) {
            _incrementScore(_targetId, r.overallScore);
        }

        emit ReviewStatusUpdated(_targetId, _reviewIndex, oldStatus, _newStatus);
    }

    // ── 读取函数 ──────────────────────────────────────
    function getReviews(bytes32 _targetId)
        external view returns (Review[] memory)
    {
        return targetReviews[_targetId];
    }

    function getReviewCount(bytes32 _targetId)
        external view returns (uint256)
    {
        return targetReviews[_targetId].length;
    }

    // 读取时再做除法，永远只截断一次
    function getReputationScore(bytes32 _targetId)
        external view returns (uint128)
    {
        TargetStats storage stats = targetStats[_targetId];
        if (stats.reviewCount == 0) return 0;
        return stats.totalScore / stats.reviewCount;
    }

    // ── 内部函数：增量增加总分 ────────────────────────
    function _incrementScore(bytes32 _targetId, uint8 _score) internal {
        TargetStats storage stats = targetStats[_targetId];
        stats.totalScore += uint128(_score) * 100;
        stats.reviewCount += 1;
    }

    // ── 内部函数：增量减少总分 ────────────────────────
    function _decrementScore(bytes32 _targetId, uint8 _score) internal {
        TargetStats storage stats = targetStats[_targetId];
        stats.totalScore -= uint128(_score) * 100;
        if (stats.reviewCount > 0) stats.reviewCount -= 1;
    }
}