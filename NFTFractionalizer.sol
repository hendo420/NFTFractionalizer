pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTFractionalizer is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _fractionalTokenCounter;

    struct FractionalTokenInfo {
        address nftContract;
        uint256 tokenId;
        bool isERC1155;
    }

    mapping(address => FractionalTokenInfo) public fractionalTokenToNFT;

    function fractionalizeERC721(
        address nftContract,
        uint256 tokenId,
        uint256 totalSupply
    ) public {
        IERC721 erc721 = IERC721(nftContract);
        require(erc721.ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");

        FractionalToken fractionalToken = new FractionalToken(totalSupply);
        address fractionalTokenAddress = address(fractionalToken);

        erc721.safeTransferFrom(msg.sender, address(this), tokenId);

        FractionalTokenInfo memory tokenInfo = FractionalTokenInfo({
            nftContract: nftContract,
            tokenId: tokenId,
            isERC1155: false
        });

        fractionalTokenToNFT[fractionalTokenAddress] = tokenInfo;

        fractionalToken.transfer(msg.sender, totalSupply);
    }

    function fractionalizeERC1155(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 totalSupply
    ) public {
        IERC1155 erc1155 = IERC1155(nftContract);
        require(erc1155.balanceOf(msg.sender, tokenId) >= amount, "Insufficient NFT balance");

        FractionalToken fractionalToken = new FractionalToken(totalSupply);
        address fractionalTokenAddress = address(fractionalToken);

        erc1155.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        FractionalTokenInfo memory tokenInfo = FractionalTokenInfo({
            nftContract: nftContract,
            tokenId: tokenId,
            isERC1155: true
        });

        fractionalTokenToNFT[fractionalTokenAddress] = tokenInfo;

        fractionalToken.transfer(msg.sender, totalSupply);
    }

    function defractionalize(address fractionalTokenAddress) public {
        FractionalToken fractionalToken = FractionalToken(fractionalTokenAddress);
        uint256 totalSupply = fractionalToken.totalSupply();

        require(fractionalToken.balanceOf(msg.sender) == totalSupply, "Must own all fractional tokens");

        FractionalTokenInfo memory tokenInfo = fractionalTokenToNFT[fractionalTokenAddress];

        fractionalToken.burn(msg.sender, totalSupply);

        if (tokenInfo.isERC1155) {
            IERC1155(tokenInfo.nftContract).safeTransferFrom(address(this), msg.sender, tokenInfo.tokenId, totalSupply, "");
        } else {
            IERC721(tokenInfo.nftContract).safeTransferFrom(address(this), msg.sender, tokenInfo.tokenId);
        }
    }
}

contract FractionalToken is ERC20, Ownable {
    constructor(uint256 totalSupply) ERC20("FractionalToken", "FT") {
_mint(_msgSender(), totalSupply);
}

function burn(address account, uint256 amount) public onlyOwner {
    _burn(account, amount);
}

