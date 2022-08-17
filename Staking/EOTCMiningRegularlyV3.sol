// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./EOTCMiningRegularlyStorageV3.sol";


contract EOTCMiningRegularlyV3 is Ownable, EOTCMiningRegularlyStorageV3{

    // 铸造Token
    event MintedToken(address account, uint256 amount, uint256 month, uint256 startTime);
    // 存款质押
    event Deposit(address account, uint256 amount, uint256 month, uint256 startTime);
    // 添加储备金
    event AddReserves(address token, address from, address to, uint256 value);
    // 收获
    event Reward(address account, uint256 deposit, uint256 reward);
    // 移除周期年化率
    event RemoveInvestYearRate(uint256 cycle, uint256 yearRate);
    // 设置周期年化率
    event SetInvestYearRate(uint256 cycle, uint256 yearRate);

    address public immutable _EOTC;

    using SafeMath for uint256;

    // 构造函数
    constructor(address _eotc) public {
        _EOTC = _eotc;
    }

    // 查询当前合约EOTC余额
    function eotc() public view returns(uint256){
        return IERC20(_EOTC).balanceOf(address(this));
    }

    // 设置投资年化率
    function setInvestYearRate(uint256 cycle, uint256 yearRate) external onlyOwner {
        require(yearRate > 0, "Annualized rate is less than zero");
        investYearRate[cycle] = yearRate;
        stage.push(cycle);
        emit SetInvestYearRate(cycle, yearRate);
    }

    // 移除投资年化率
    function removeInvestYearRate(uint256 cycle) external onlyOwner {
        uint256 yearRate = investYearRate[cycle];
        require(yearRate > 0, "Investment cycle does not exist");
        delete investYearRate[cycle];

        // 移除周期数组
        uint len = stage.length;
        uint index = len;
        for (uint i = 0; i < stage.length; i++) {
            if (stage[i] == cycle) {
                index = i;
                break;
            }
        }
        stage[index] = stage[len - 1];
        stage.pop();
        emit RemoveInvestYearRate(cycle, yearRate);
    }


    function invest(address account, uint256 amount, uint256 investType) internal returns(uint256){
        // 校验周期
        uint256 rate = investYearRate[investType];
        require(rate > 0, "Wrong type of investment");
        // 计算利息
        uint256 multiple = investType.mul(1e6).div(year);
        rate = rate.mul(multiple).div(1e6);
        uint256 profit = amount.mul(rate).div(1e6);
        // 校验储备金是否充足
        require(totalInterest + profit <= totalReserves, "Insufficient liquidity reserves");

        TotalInterest storage ti = accrueInterest[investType];
        ti.amount += amount;
        ti.interest += profit;

        totalInterest += profit;

        // 保存质押记录
        uint256 accrueInterestTime = block.timestamp - oneDayTime;
        Pledge[] storage order = _pledge[account][investType];
        uint256 length = order.length;
        Pledge memory vars;
        vars.id = length += 1;
        vars.cycle = investType;
        vars.startTime = accrueInterestTime;
        vars.amount = amount;
        vars.reward = profit;
        vars.isStop = true;

        order.push(vars);
        return accrueInterestTime;
    }

    // 铸造凭证
    function minted(address account, uint256 amount, uint256 investType) external onlyOwner {
        require(account != address(0), "Cannot be zero address");
        // 质押记录
        uint256 startTime = invest(account, amount, investType);
        // 质押转账
        IERC20(_EOTC).transferFrom(msg.sender, address(this), amount);
        totalEOTC += amount;
        emit MintedToken(account, amount, investType, startTime);
    }

    // 批量铸造凭证
    function mintedBatch(address[] memory account, uint256[] memory amount, uint256 investType) external onlyOwner{
        require(account.length > 0, "Arrays length mismatch");

        uint256 sum;
        for (uint j = 0; j < amount.length; j++) {
            sum += amount[j];
        }
        uint256 balance = IERC20(_EOTC).balanceOf(msg.sender);
        require(balance >= sum, "Insufficient balance");

        for(uint i = 0; i < account.length; i++){
            uint256 startTime = invest(account[i], amount[i], investType);

            emit MintedToken(account[i], amount[i], investType, startTime);
        }
        IERC20(_EOTC).transferFrom(msg.sender, address(this), sum);
        totalEOTC += sum;
    }

    // 减少储备
    /*function reduceReserves(uint256 value) external onlyOwner{
        if(value <= 0){
            value = IERC20(_EOTC).balanceOf(address(this));
        }
        IERC20(_EOTC).transfer(owner(), value);
        emit ReduceReserves(_EOTC, address(this), owner(), value);
    }*/

    // 添加储备
    function addReserves(uint256 value) external onlyOwner{
        require(value > 0, "Cannot be zero");

        IERC20(_EOTC).transferFrom(msg.sender, address(this), value);
        totalReserves += value;
        emit AddReserves(_EOTC, address(this), msg.sender, value);
    }

    // 存款质押
    function deposit(uint256 amount, uint256 investType) external {
        require(amount > 0, "Must be greater than zero");

        uint256 startTime = invest(msg.sender, amount, investType);
        IERC20(_EOTC).transferFrom(msg.sender, address(this), amount);

        totalEOTC += amount;
        emit Deposit(msg.sender, amount, investType, startTime);
    }

    // 收获
    function reward(uint256 investType, uint256 orderId) external {
        Pledge[] memory orders = _pledge[msg.sender][investType];
        uint256 index = orderId - 1;
        uint256 amount = orders[index].amount;
        uint256 rewards = orders[index].reward;
        require(amount > 0, "Order does not exist");
        require(orders[index].isStop, "The order has expired and redeemed");

        // 当前时间
        uint256 currentTime = block.timestamp;
        // 校验是否到期
        uint256 time = thirtyDaysTime.mul(investType);
        uint256 maturityTime = orders[index].startTime.add(time);
        require(currentTime >= maturityTime, "The current order pledge has not expired");

        // 校验质押奖励是否充足
        uint256 actualReward = amount + rewards;
        uint256 eotcAmount = eotc();
        require(actualReward <= eotcAmount, "The deposit amount does not match the deposit amount");

        // 领取 收获 = 本金 + 利息
        IERC20(_EOTC).transfer(msg.sender, actualReward);

        totalInterest -= rewards;
        totalReserves -= rewards;
        totalAmount += amount;
        totalReward += rewards;

        TotalInterest storage ti = accrueInterest[investType];
        ti.amount -= amount;
        ti.interest -= rewards;
        Pledge[] storage pl = _pledge[msg.sender][investType];
        pl[index].isStop = false;
        emit Reward(msg.sender, amount, rewards);
    }

    // 重塑利润
    function replantSeeds(uint256 investType, uint256 orderId) external {
        Pledge[] memory orders = _pledge[msg.sender][investType];
        uint256 index = orderId - 1;
        uint256 amount = orders[index].amount;
        uint256 rewards = orders[index].reward;
        require(amount > 0, "Order does not exist");
        require(orders[index].isStop, "The order has expired and redeemed");

        // 当前时间
        uint256 currentTime = block.timestamp;
        // 校验是否到期
        uint256 time = thirtyDaysTime.mul(investType);
        uint256 maturityTime = orders[index].startTime.add(time);
        require(currentTime >= maturityTime, "The current order pledge has not expired");

        // 领取
        totalInterest -= rewards;
        totalReserves -= rewards;
        totalAmount += amount;
        totalReward += rewards;

        TotalInterest storage ti = accrueInterest[investType];
        ti.amount -= amount;
        ti.interest -= rewards;

        Pledge[] storage pl = _pledge[msg.sender][investType];
        pl[index].isStop = false;
        emit Reward(msg.sender, amount, rewards);

        // 二次质押
        uint256 actualReward = amount + rewards;
        uint256 startTime = invest(msg.sender, actualReward, investType);

        totalEOTC += actualReward;
        emit Deposit(msg.sender, actualReward, investType, startTime);
    }

    // 预估收益1
    function depositEstimateReward(uint256 amount, uint256 investType) external view returns(uint256, uint256){
        uint256 rate = investYearRate[investType];
        require(rate > 0, "Wrong type of investment");
        // 总收益
        uint256 multiple = investType.mul(1e6).div(year);
        rate = rate.mul(multiple).div(1e6);
        uint256 totalIncome = amount.mul(rate).div(1e6);

        // 计算日收益
        uint256 totalDay = investType.mul(30);
        uint256 dailyIncome = totalIncome.div(totalDay);
        return (totalIncome, dailyIncome);
    }

    // 查询单周期质押到期订单
    function expiresOrders(address account, uint256 investType) external view returns(uint256, Pledge[] memory){
        Pledge[] memory orders = _pledge[account][investType];

        uint256 length = orders.length;
        Pledge[] memory pl = new Pledge[](length);
        uint256 currentTime = block.timestamp;
        uint256 index;
        if(orders.length > 0){
            uint256 time = thirtyDaysTime.mul(investType);
            for(uint i = 0; i < orders.length; i++){
                if(orders[i].isStop){
                    uint256 current = orders[i].startTime.add(time);
                    if(currentTime >= current){
                        pl[index] = orders[i];
                        index += 1;
                    }
                }
            }
        }

        uint256 len;
        Pledge[] memory order = new Pledge[](index);
        for (uint x = 0; x < pl.length; x++){
            if (pl[x].amount > 0){
                order[len] = pl[x];
                len += 1;
            }
        }
        return (currentTime, order);
    }

    // 查询全部质押到期订单
    function allExpiresOrders(address account) external view returns(uint256, Pledge[] memory){

        uint256 length;
        for(uint y = 0; y < stage.length; y++){
            Pledge[] memory pl = _pledge[account][stage[y]];
            length += pl.length;
        }

        Pledge[] memory pledges = new Pledge[](length);
        uint256 currentTime = block.timestamp;
        uint256 index;
        uint256 time;
        uint256 current;
        for(uint i = 0; i < stage.length; i++){
            time = thirtyDaysTime.mul(stage[i]);
            Pledge[] memory order = _pledge[account][stage[i]];
            for(uint j = 0; j < order.length; j++){
                if(order[j].isStop){
                    current = order[j].startTime.add(time);
                    if(currentTime >= current){
                        pledges[index] = order[j];
                        index += 1;
                    }
                }
            }
        }

        uint256 len;
        Pledge[] memory orders = new Pledge[](index);
        for (uint x = 0; x < pledges.length; x++){
            if (pledges[x].amount > 0){
                orders[len] = pledges[x];
                len += 1;
            }
        }
        return (currentTime, orders);
    }

    // 获取项目方需要划转的利息
    function estimateInterest() external view returns(uint256, uint256){
        uint256 total;
        uint256 income;
        for (uint i = 0; i < stage.length; i++) {
            total += accrueInterest[stage[i]].amount;
            income += accrueInterest[stage[i]].interest;
        }
        // 本金，利息
        return (total, income);
    }

    // 用户质押记录
    function pledge(address account, uint256 investType) external view returns(uint256, Pledge[] memory){
        uint256 currentTime = block.timestamp;
        Pledge[] memory pl = _pledge[account][investType];
        return (currentTime, pl);
    }

    // 全部质押记录
    function allPledge(address account) external view returns(uint256, Pledge[] memory){
        uint256 currentTime = block.timestamp;

        uint256 length;
        for (uint y = 0; y < stage.length; y++) {
            Pledge[] memory pl = _pledge[account][stage[y]];
            length += pl.length;
        }

        Pledge[] memory orders = new Pledge[](length);
        uint256 index;
        for (uint i = 0; i < stage.length; i++) {
            Pledge[] memory pledges = _pledge[account][stage[i]];
            for(uint j = 0; j < pledges.length; j++){
                orders[index] = pledges[j];
                index += 1;
            }
        }
        return (currentTime, orders);
    }

    // 质押数量
    function pledgeAmount(address account) external view returns(uint256, uint256[] memory){
        uint256 amount;
        uint256[] memory list = new uint256[](stage.length);
        for (uint i = 0; i < stage.length; i++) {
            Pledge[] memory pl = _pledge[account][stage[i]];
            uint256 cycleAmount;
            for (uint j = 0; j < pl.length; j++) {
                if(pl[j].isStop){
                    amount += pl[j].amount;
                    cycleAmount += pl[j].amount;
                }
            }
            list[i] = cycleAmount;
        }
        return (amount, list);
    }

}
