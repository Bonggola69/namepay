// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/// @title MockAgentID — minimal ERC-721 stand-in for the Agent ID contract
/// @notice Only implements what NamePay uses: ownerOf(tokenId). The owner of
/// each name is preset in the constructor as (labelhash => owner) pairs.
/// Unclaimed names revert with ERC721NonexistentToken, like the real contract.
contract MockAgentID {
    error ArrayLengthMismatch();

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    /// @param tokenIds Labelhashes, i.e. keccak256(bytes(label)) per name.
    /// @param owners The owner address for each labelhash, in the same order.
    constructor(bytes32[] memory tokenIds, address[] memory owners) {
        if (tokenIds.length != owners.length) revert ArrayLengthMismatch();
        for (uint256 i; i < tokenIds.length; ++i) {
            _owners[uint256(tokenIds[i])] = owners[i];
            unchecked {
                ++_balances[owners[i]];
            }
        }
    }

    /// @notice Test-only helper: sets the owner of a token id. Used by tests
    /// that etch this mock's code onto the real Agent ID address (where the
    /// constructor-set storage would otherwise be empty).
    function setOwner(uint256 tokenId, address owner) external {
        address previous = _owners[tokenId];
        if (previous != address(0)) {
            unchecked {
                --_balances[previous];
            }
        }
        _owners[tokenId] = owner;
        if (owner != address(0)) {
            unchecked {
                ++_balances[owner];
            }
        }
    }

    /// @notice Returns the owner of a token id, or reverts if never claimed.
    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert IERC721Errors.ERC721NonexistentToken(tokenId);
        return owner;
    }

    /// @notice Returns how many names an account owns (1 per name in this mock).
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}
