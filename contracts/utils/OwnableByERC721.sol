// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title Ownable By ERC721
/// @dev Contract to make other contracts ownable by an ERC721 token for access control
contract OwnableByERC721 {
    address private _nftAddress;

    /**
        @dev Modifier to restrict ops to only the owner
     */
    modifier onlyOwner() {
        require(owner() == msg.sender, "OwnableByERC721: caller is not the owner");
        _;
    }

    /**
        @dev Sets the NFT factory address
        @param nftAddress Address of the NFT factory
     */
    function _setNFT(address nftAddress) internal {
        _nftAddress = nftAddress;
    }

    /**
        @dev Returns the NFT factory address that created this NFT
        @return nftAddress Address of the NFT factory
     */
    function nft() public view virtual returns (address nftAddress) {
        return _nftAddress;
    }

    /**
        @dev Returns the owner of the NFT
        @return ownerAddress Address of the owner
     */
    function owner() public view virtual returns (address ownerAddress) {
        return IERC721(_nftAddress).ownerOf(uint256(uint160(address(this))));
    }
}
