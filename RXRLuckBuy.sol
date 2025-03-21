// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";


// 夺宝开奖合约，射幸游戏

contract RXRLuckyBuy is VRFConsumerBaseV2Plus{
    struct LotteryInfo {
        uint256 total; //总参与人数       
        uint256 blockNumber; //开奖区块号
        uint256 requestId; //开奖时间戳
        uint256 code; //中奖码
    }
    mapping(uint256 => LotteryInfo) public _lotteryInfo; 
    
    event DrawLottery(uint256, uint256);

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        bool hasUsed;
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */

    // Your subscription ID.
    uint256 public s_subscriptionId;

    // Past request IDs.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/vrf/v2-5/supported-networks
    bytes32 public keyHash =
        // 0xb94a4fdb12830e15846df59b27d7c5d92c9c24c10cf6ae49655681ba560848dd; //正式
        0x8596b430971ac45bdf6088665b9ad8e8630c9d5049ab54b14dff711bee7c0e26; //测试

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 public callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
    uint32 public numWords = 2;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0xd691f04bc0C9a24Edb78af9E005Cf85768F694C9  //正式
     * COORDINATOR: 0xDA3b641D438362C440Ac5458c57e00a712b66700  //测试
     */
    constructor(
        uint256 subscriptionId
    ) VRFConsumerBaseV2Plus(0xDA3b641D438362C440Ac5458c57e00a712b66700) {
        s_subscriptionId = subscriptionId;
    }

    //只能由平台来开奖，开奖机制类似彩票，由平台随机抽出幸运者
    function drawLottery(uint256 _pid, uint256 _total) external onlyOwner {
        require(_total > 0, "Total must be greater than zero");
        require(_lotteryInfo[_pid].code == 0, "The period has already been awarded");
        require(s_requests[lastRequestId].exists, "request not found");
        require(s_requests[lastRequestId].hasUsed == false, "Random has used, new it again"); 
        require(s_requests[lastRequestId].randomWords[0] > 0, "Random must bigger than zero");  
        s_requests[lastRequestId].hasUsed = true;   
        uint256 random = s_requests[lastRequestId].randomWords[0] % _total + 1;

        LotteryInfo memory info = LotteryInfo(_total, block.number, lastRequestId, random);
        _lotteryInfo[_pid] = info;

        emit DrawLottery(_pid, random);  
    }

    //查询中奖号码
    function getLotteryCode(uint256 _pid) external view returns (uint256){
      return _lotteryInfo[_pid].code;
    }

    // Assumes the subscription is funded sufficiently.
    // @param enableNativePayment: Set to `true` to enable payment in native tokens, or
    // `false` to pay in LINK
    function requestRandomWords(
        bool enableNativePayment
    ) public onlyOwner returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: enableNativePayment
                    })
                )
            })
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            hasUsed: false,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    // function getRequestStatus(
    //     uint256 _requestId
    // ) external view returns (uint256[] memory randomWords) {
    //     require(s_requests[_requestId].exists, "request not found");
    //     RequestStatus memory request = s_requests[_requestId];
    //     return (request.randomWords);
    // }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

}