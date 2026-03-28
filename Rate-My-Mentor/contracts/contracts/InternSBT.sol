// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract InternSBT is ERC721 {
    using ECDSA for bytes32;

    // ── 数据结构────────────────────────────
    struct InternCredential {
        bytes32 companyDomainHash;  // bytes32 替换 string，省 Gas
        uint32  internStart;
        bool    isVerified;
    }

    // ── 状态变量 ──────────────────────────────────────
    address public trustedBackend;
    uint256 private _tokenIdCounter;//编号，第一个人1号，第二个人2号

    mapping(address => InternCredential) public credentials;
    mapping(address => bool) public hasSBT;

    // ── 事件 ──────────────────────────────────────────
    event SBTMinted(address indexed to, bytes32 companyDomainHash, uint256 tokenId);

    // ── 构造函数 ──────────────────────────────────────
    constructor(address _trustedBackend) ERC721("InternSBT", "ISBT") {//整套认证统一叫"InternSBT", 简称"ISBT"
        trustedBackend = _trustedBackend;
    }

    // ── 核心函数：铸造 SBT ────────────────────────────
    function mintSBT(
        bytes32 _companyDomain,
        uint32  _internStart,
        bytes memory _signature
    ) external {
        // 1. 每个钱包只能有一个 SBT
        require(!hasSBT[msg.sender], "Already has SBT");

        // 2. 验证后端签名（加入 chainId 防重放攻击）
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                msg.sender,
                _companyDomain,
                _internStart,
                block.chainid    // ← 防止跨链重放
            )
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedHash, _signature);
        require(signer == trustedBackend, "Invalid signature");

        // 3. 铸造
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(msg.sender, tokenId);

        // 4. 存储凭证
     credentials[msg.sender] = InternCredential({
    companyDomainHash: keccak256(abi.encodePacked(_companyDomain)),
    internStart: _internStart,
    isVerified: true
});
        hasSBT[msg.sender] = true;

        emit SBTMinted(msg.sender, _companyDomain, tokenId);
    }

    // ── 新增：获取 credentialId ───────────────────
function getCredentialId(address _holder)
    external view returns (bytes32)
{
    require(hasSBT[_holder], "No SBT found");
    return credentials[_holder].companyDomainHash;  // ← 改这里
}

    // ── 灵魂绑定：禁止转让 ────────────────────────────
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(from == address(0), "SBT: non-transferable");
        return super._update(to, tokenId, auth);
    }

    // ── 工具函数：域名转 bytes32（前端调用参考）────────
    // 前端传参时用 ethers.js:
    // ethers.encodeBytes32String("bytedance.com")
}