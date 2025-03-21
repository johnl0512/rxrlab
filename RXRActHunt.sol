// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RXRToken.sol";

// 用户夺宝挖矿隔期释放
// 隔期释放，eg:第3期购买，第5期释放


contract RXRActHunt is Ownable{
    struct ActInfo {
        uint256 period; //购买时周期
        uint256 amount; //购买数量单位 Ether
    }
    mapping(address => ActInfo[]) private _actInfos; //节点购买者账户地址+购买时所在周期，支持多期多次购买
    mapping(address => uint256) private _pullPeriod; //用户最近成功提现的周期数
    mapping(address => uint256) private _withdrawInfos;  //用户已提现数量
    mapping(address => uint256) private _noWithdrawInfos;  //用户未提现数量
    mapping(address => uint256) private _allWithdrawInfos;  //用户可提现总量，包括已提和未提
    uint256 private _totalHunt;  //挖矿总量
    uint256 public _lastSales; //上周期累计销量
    uint256 public _curPeriod; //当前销售周期
    IERC20 public _rxrToken; //ERC20合约地址
    address public _fromAddress;
    


    event Hunt(address,uint256);
    event Withdraw(address,uint256);
    event UpdatePeriod(uint256);

    constructor(address initialOwner,address rxrAddress) Ownable(initialOwner) {
        _curPeriod = 1;
        _totalHunt = 0;
        _fromAddress = 0xe01373e9440bdf94b296b1376a45e7aCf13a41df;    //正式部署时初始化,出纳地址
        _rxrToken = IERC20(rxrAddress);
    }

    //单笔挖矿有最大额限制100000。amount单位为Wei；
    function hunt(address user, uint256 amount) external onlyOwner {
        require(amount > 0, "amount must be greater than zero");
        require(amount < 100000*10**18, "invalid amount");
        ActInfo memory info = ActInfo(_curPeriod, amount);
        _actInfos[user].push(info);
        _allWithdrawInfos[user] += amount;
        _noWithdrawInfos[user] += amount;
        _totalHunt += amount;

        emit Hunt(user, amount);      
    }

    //用户提现，隔期提现
    function withdraw() external {
        require(_pullPeriod[msg.sender] < _curPeriod, "It's not time to unfreeze");
        require(_noWithdrawInfos[msg.sender] > 0, "No remaining tokens to withdraw");

        ActInfo[] memory actInfos = _actInfos[msg.sender];

        //提现并统计已提现总数
        uint256 withdrawAmount = 0;       
        
        for(uint256 i=0; i < actInfos.length; i++) {
            int offset = int(_curPeriod) - int(actInfos[i].period);
            if(offset <= 0){
                continue;
            }

            int temp = int(_pullPeriod[msg.sender]) - int(actInfos[i].period);
            int pullset = temp > 0 ? temp : int(0);
            if(pullset >= 2){
                continue;
            }
            if(offset >=  2){  // >=2的已经提现
                withdrawAmount += actInfos[i].amount;
            }
        }

        require(withdrawAmount > 0, "Invalid withdrawal amount");   
        _pullPeriod[msg.sender] = _curPeriod;  //当前周期可提现的已经全部提现   
        // 进行配额检查
        uint256 allowed = _rxrToken.allowance(_fromAddress, address(this));
        require(allowed >= withdrawAmount, "Transfer amount exceeds allowance");
        // 进行余额检查
        uint256 balance = _rxrToken.balanceOf(_fromAddress);
        require(balance >= withdrawAmount, "Transfer amount exceeds balance");    
        _rxrToken.transferFrom(_fromAddress, msg.sender, withdrawAmount);
        _withdrawInfos[msg.sender] += withdrawAmount;
        _noWithdrawInfos[msg.sender] -= withdrawAmount;
        
        emit Withdraw(msg.sender, withdrawAmount);
    }

    //get累计销售额以计算_curPeriod，_totalSales当前累计销售额，单位U。每个销售周期内须更新至少一次，重复执行无碍，不能遗漏。
    function setCurPeriodBySales(uint256 _totalSales) external onlyOwner {
        require(_totalSales - _lastSales > 0, "Invalid input");
        uint256 p = _curPeriod - 1;
        uint256 t = 12 ** p * 1000000;
        require(t > 0,"No period are required");
        uint256 tmpPeriod = _curPeriod + (_totalSales - _lastSales) * 10 ** p / t;
        require (tmpPeriod == _curPeriod + 1, "No sales are required");
        _curPeriod = tmpPeriod;
        _lastSales += t/(10 ** p);   

        emit UpdatePeriod(_curPeriod);    
    }

    //已提取
    function balanceOfYes(address _user) external view returns (uint256) {
        return _withdrawInfos[_user];
    }

    //未提取
    function balanceOfNo(address _user) external view returns (uint256) {
        return _noWithdrawInfos[_user];
    }

     //已提+未提
    function balanceOfAll(address _user) external view returns (uint256) {
        return _allWithdrawInfos[_user];
    }

    //可提未提
    function balanceOfMay(address _user) external view returns (uint256) {
        ActInfo[] memory actInfos = _actInfos[_user];
        uint256 mayWithdrawAmount = 0;       
        for(uint256 i=0; i < actInfos.length; i++) {
            int offset = int(_curPeriod) - int(actInfos[i].period);
            int pullset = int(_pullPeriod[_user]) - int(actInfos[i].period);
            if(pullset >= 2){
                continue;
            }
            if(offset >=  2){  // >=2的已经提现
                mayWithdrawAmount += actInfos[i].amount;
            }
        }

        return mayWithdrawAmount;
    }

    //已hunt产出RXR总数
    function totalHunt() external view returns (uint256){
      return _totalHunt;
    }

}