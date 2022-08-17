// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract EOTCMiningRegularlyStorageV3 {

    // 投资天数(年)
    // TODO 记录一年12月
    uint256 internal constant year = 12;

    // 释放时间总长(月)
    // TODO 记录1/30天时间戳
    uint256 internal constant thirtyDaysTime = 2592000;
    uint256 internal constant oneDayTime = 86400;

    // 投资天数(月)
    uint256[] internal stage;

    // 周期-年化率映射
    mapping(uint256 => uint256) public investYearRate;

    struct Pledge {
        uint256 id;         // 订单ID
        uint256 cycle;      // 质押周期
        uint256 startTime;  // 质押时间
        uint256 amount;     // 质押数量
        uint256 reward;     // 质押收获
        bool isStop;        // 质押到期
    }

    // 质押记录
    mapping(address => mapping(uint256 => Pledge[])) internal _pledge;

    struct TotalInterest {
        uint256 amount;     // 质押数量
        uint256 interest;   // 应计利息
    }
    // 总质押本金、利息
    mapping(uint256 => TotalInterest) public accrueInterest;

    // 总质押利息
    uint256 public totalInterest;

    // 总EOTC质押记录
    uint256 public totalEOTC;

    // 总利息储备金
    uint256 public totalReserves;

    // 总收获本金
    uint256 public totalAmount;

    // 总奖励
    uint256 public totalReward;
}
