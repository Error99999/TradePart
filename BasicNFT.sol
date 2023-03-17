// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNFT is ERC721 {
    uint256 private s_tokenC;
    string public constant TOKEN_URI =
        "ipfs://bafybeihn63yfs7bwpsojz565cgv3hntwuir4yk4o3gwpuf5eg2yiieu7nm";

    constructor() ERC721("TestNFT", "TN") {
        s_tokenC = 0;
    }

    //NFT一开始属于合约部署者
    function mintNft() public returns (uint256) {
        //生成NFT_safe方法传入的是NFT拥有者的地址,和合约生成的NFT 编号
        _safeMint(msg.sender, s_tokenC);
        s_tokenC = s_tokenC + 1;
        return s_tokenC;
    }

    //NFT元数据实际存放的位置
    function tokenURI(
        uint256 /*tokenId*/
    ) public view override returns (string memory) {
        return TOKEN_URI;
    }

    function getTokenC() public view returns (uint256) {
        return s_tokenC;
    }
}
