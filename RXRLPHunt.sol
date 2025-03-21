// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RXRToken.sol";

// 限量发售4000个节点，每个节点释放10000（1万）个RXR Coin代币，共计4000万枚RXR Coin代币（即4000万股RXR.lab平台股权）
// 5期释放完毕,
// 可释放周期数由人为设定 curNop  number of period
// 可释放量 1W * curNop / 5;
// 用可提取量，已提取量，剩余可提取量
// 本阶段共计释放1.3亿枚RXR Coin代币（即原始股共计为1.3亿股），其中：平台认购5000万枚代币（即5000万股），节点计划认购人认购4000万枚代币（即4000万股），做市商战略投资人认购4000万枚代币（即4000万股,没锁定期）。
// 8000万
// 战略投资4000万，节点+战略总数控制在8000万
// 战略投资直接释放
// 平台方5000W，分5期释放


contract RXRLPHunt is Ownable{
    struct LPInfo {
        uint256 period; //购买时周期
        uint256 amount; //购买数量，份数
    }
    mapping(address => LPInfo[]) private _lpInfos; //节点购买者账户地址+购买时所在周期，支持多期多次购买
    mapping(address => uint256) private _pullPeriod; //用户最近提现周期
    mapping(address => uint256) private _withdrawInfos;  //用户已提现数量
    mapping(address => uint256) private _noWithdrawInfos;  //用户未提现数量
    mapping(address => uint256) private _allWithdrawInfos;  //总量 已提+未提
    mapping(address => uint256) private _investInfos; //节点购买者已提取代币数量
    uint256 public _totalLPHunt;  //节点已释放数量
    // uint256 public _totalInvestHunt;  //战略投资已释放数量
    uint256 public _maxLPCounter; //节点投资数上限
    uint256 public _maxInvestCounter; //战略投资数上限
    uint256 public _platHolding; //平台持有
    uint256 public _lastSales; //上周期累计销量
    uint256 public _curPeriod; //当前销售周期
    IERC20 public _rxrToken; //ERC20合约地址
    address public _fromAddress;
    
    event Invest(address,uint256);
    event LPHunt(address,uint256);
    event Withdraw(address,uint256);
    event PlatHunt(address);
    event PlatWithdraw(address,uint256);
    event UpdatePeriod(uint256);

    constructor(address initialOwner,address rxrAddress) Ownable(initialOwner) {
        _maxLPCounter = 40000000 * 10 ** 18;
        _maxInvestCounter = 40000000 * 10 ** 18;
        _lastSales = 0;
        _curPeriod = 1;    
        _totalLPHunt = 0;
        _platHolding = 0;
        _fromAddress = 0xe01373e9440bdf94b296b1376a45e7aCf13a41df; //部署时更换，出纳地址
        _rxrToken = IERC20(rxrAddress);  
    }

   //节点购买。_num购买份数,可多期多次购买,  权限控制有问题，待商定处理？？？？？
    function lpHunt(address user, uint256 _num) external onlyOwner {
        require(_num > 0, "_num must be greater than zero");
        LPInfo memory _info = LPInfo(_curPeriod, _num);
        _lpInfos[user].push(_info);

        _totalLPHunt += _num * 10000 * 10**18;
        _noWithdrawInfos[user] += _num * 10000 * 10**18;
        _allWithdrawInfos[user] += _num * 10000 * 10**18;
        emit LPHunt(user, _num);      
    }

    //提现,分5期释放
    function withdraw() external {
        require(_pullPeriod[msg.sender] < _curPeriod, "It's not time to unfreeze");
        require(_noWithdrawInfos[msg.sender] > 0, "No remaining tokens to withdraw");

        LPInfo[] memory lpInfos = _lpInfos[msg.sender];
        uint256 withdrawAmount = 0;       

        for(uint256 i=0; i < lpInfos.length; i++) {
            int offset = 0;
            int tempOff = int(_curPeriod) - int(lpInfos[i].period);
            if(tempOff > 0){
                offset = tempOff;
            }else{
                continue ;
            }
            
            int tempPull = int(_pullPeriod[msg.sender]) - int(lpInfos[i].period);
            int pullset = tempPull > 0 ? tempPull : int(0);

            if(pullset >= 5){
                continue;
            }
            if(offset >= 5){
                require(5-pullset >= 0, "invalid param1");
                withdrawAmount += uint256(5-pullset) * lpInfos[i].amount * 2000*10**18;
            }else{
                require(offset-pullset >= 0, "invalid param2");
                withdrawAmount += uint256(offset-pullset) * lpInfos[i].amount * 2000*10**18;
            }
        }

        require(withdrawAmount > 0, "Invalid withdrawal amount");   
        _pullPeriod[msg.sender] = _curPeriod; //购买周期=提现周期，提现金额为 (提现周期-购买周期)*amount*10000
        _withdrawInfos[msg.sender] += withdrawAmount;
        _noWithdrawInfos[msg.sender] -= withdrawAmount;
        // 进行配额检查
        uint256 allowed = _rxrToken.allowance(_fromAddress, address(this));
        require(allowed >= withdrawAmount, "Transfer amount exceeds allowance");
        // 进行余额检查
        uint256 balance = _rxrToken.balanceOf(_fromAddress);
        require(balance >= withdrawAmount, "Transfer amount exceeds balance");

        bool success = _rxrToken.transferFrom(_fromAddress, msg.sender, withdrawAmount);
        require(success, "Transfer failed");

        emit Withdraw(msg.sender, withdrawAmount);
        
    }

    //项目方预留5000W,分5期释放
    function platHunt(address _platAddress) external onlyOwner {
        require(_platHolding < 50000000 * 10 ** 18, "invalid input");
        uint256 _num = 5000;
        LPInfo memory _info = LPInfo(_curPeriod, _num);
        _lpInfos[_platAddress].push(_info);

        _platHolding += _num * 10000 * 10**18;
        _noWithdrawInfos[_platAddress] += _num * 10000 * 10**18;
        _allWithdrawInfos[_platAddress] += _num * 10000 * 10**18;
        emit PlatHunt(_platAddress);      
    }

    //totalSales累计销售额以计算_curPeriod，_totalSales当前累计销售额，单位U。每个销售周期内须更新至少一次，重复执行无碍，不能遗漏。
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
        require(_lpInfos[_user].length > 0, "User does not have any LPInfo");

        LPInfo[] memory lpInfos = _lpInfos[_user];
        uint256 withdrawAmount = 0;       

        for(uint256 i=0; i < lpInfos.length; i++) {
            int offset = 0;
            int tempOff = int(_curPeriod) - int(lpInfos[i].period);
            if(tempOff > 0){
                offset = tempOff;
            }else{
                continue ;
            }
            
            int tempSet = int(_pullPeriod[_user]) - int(lpInfos[i].period);
            int pullset = tempSet > 0 ? tempSet : int(0);

            if(pullset >= 5){
                continue;
            }
            if(offset >= 5){
                require(5-pullset >= 0, "invalid param1");
                withdrawAmount += uint256(5-pullset) * lpInfos[i].amount * 2000*10**18;
            }else{
                require(offset-pullset >= 0, "invalid param2");
                withdrawAmount += uint256(offset-pullset) * lpInfos[i].amount * 2000*10**18;
            }
        }

        return withdrawAmount;
    }

    //节点投资总量
    function totalLPHunt() external view returns (uint256){
      return _totalLPHunt;
    }

    //战略投资总量
    // function totalInvestHunt() external view returns (uint256){
    //   return _totalInvestHunt;
    // }

}