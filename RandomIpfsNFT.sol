// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error RandomIpfsNFT__RandomWordNotInTheRage();
error RandomIpfsNFT__NotEnoughEth();
error RandomIpfsNFT__TransferFail();
error RandomIpfsNFT__NftIdIncorrect();
error RandomIpfsNFT__InvalidAddress();

/*
  说明：真正标识NFT的是铸造NFT时你传过去的地址(而不是token ID(NFT编号)或其他),
  随时可以调用这份签发NFT的智能合约中的ownerOf方法中查询到拥有该NFT的地址
*/
//基本功能:用户支付token随机获得不同类型的NFT,NFT的所有者可以累计余额提现
contract RandomIpfsNFT is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
    enum Type {
        NOR,
        OK,
        PER
    }
    //chainlink VRF
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptId;
    bytes32 private immutable i_totalGasLimit;
    uint32 private immutable i_callbackGaslimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    //记录请求者地址与随机数请求id的关系
    mapping(uint256 => address) private s_requestIdToSender;

    //NFT
    uint256 private s_tokenC;
    uint256 internal constant MAX_CHANCE_VALUE = 100;
    string[] internal s_tokenUris;
    uint256 internal immutable i_mintFee;
    uint256 internal s_flag;

    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(Type ctype, address owner);

    constructor(
        address vrfCoordinatorV2,
        bytes32 totalGasLimit,
        uint64 subscriptId,
        uint32 callbackGaslimit,
        string[3] memory tokenUris,
        uint256 mintFee
    ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Random photo on ipfs", "RT") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_totalGasLimit = totalGasLimit;
        i_callbackGaslimit = callbackGaslimit;
        i_subscriptId = subscriptId;
        s_tokenUris = tokenUris;
        i_mintFee = mintFee;
        s_tokenC = 0;
        s_flag = 0;
    }

    function requestNFT() public payable returns (uint256 requestId) {
        if (msg.value < i_mintFee) {
            revert RandomIpfsNFT__NotEnoughEth();
        }
        requestId = i_vrfCoordinator.requestRandomWords(
            i_totalGasLimit,
            i_subscriptId,
            REQUEST_CONFIRMATIONS,
            i_callbackGaslimit,
            NUM_WORDS
        );
        s_requestIdToSender[requestId] = msg.sender;
        emit NftRequested(requestId, msg.sender);
    }

    //获得随机数作为NFTId
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        //每个请求id对应着请求者的地址
        address ownerAddress = s_requestIdToSender[requestId];

        if (ownerAddress == address(0)) {
            revert RandomIpfsNFT__InvalidAddress();
        }

        ++s_tokenC;
        //记录每次创建完的NFTid校验防止重复
        if (s_flag == s_tokenC) {
            revert RandomIpfsNFT__NftIdIncorrect();
        }
        //随机数范围0-10,10-30,30-100不同范围获得不同的NFT ,MAX_CHANCE_VALUE用于限制根据随机数作为被除数所获得的余数范围始终在0-100
        uint256 ProbabilityN = randomWords[0] % MAX_CHANCE_VALUE;
        Type ctype = getType(ProbabilityN); //获取确定类型的NFT

        //创建NFT并设置该类型NFT的URI
        _safeMint(ownerAddress, s_tokenC);
        _setTokenURI(s_tokenC, s_tokenUris[uint256(ctype)]);

        emit NftMinted(ctype, ownerAddress);
        s_flag++;
    }

    function withdraw() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) {
            revert RandomIpfsNFT__TransferFail();
        }
    }

    /**
     * @dev 根据随机数选定NFT类型
     * @param ProbabilityN 随机数
     */
    function getType(uint256 ProbabilityN) public pure returns (Type) {
        uint256 sum = 0;
        uint256[3] memory changeArray = getChanceArray();

        for (uint256 i = 0; i < changeArray.length; i++) {
            //只有三种NFT,随机数只有三种可能性范围.判断随机数是否在三种范围当中
            if (ProbabilityN >= sum && ProbabilityN < changeArray[i]) {
                return Type(i);
            }
            sum += changeArray[i];
        }

        revert RandomIpfsNFT__RandomWordNotInTheRage();
    }

    function getChanceArray() public pure returns (uint256[3] memory) {
        return [10, 30, MAX_CHANCE_VALUE];
    }

    function getMintFee() public view returns (uint256) {
        return i_mintFee;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenC;
    }

    function getTokenUri(uint8 index) public view returns (string memory) {
        return s_tokenUris[index];
    }

    function getRequestIdToSender(uint256 requestId)
        public
        view
        returns (address)
    {
        return s_requestIdToSender[requestId];
    }
}
