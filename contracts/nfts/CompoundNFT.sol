// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Vault} from "../ERC20Vault.sol";

interface CToken {
    function mint() external payable;

    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);

    function borrow(uint256) external returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function borrowBalanceCurrent(address) external returns (uint256);

    function repayBorrow() external payable;

    function repayBorrow(uint256) external returns (uint256);
}

interface Comptroller {
    function markets(address) external returns (bool, uint256);

    function enterMarkets(address[] calldata) external returns (uint256[] memory);

    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
}

contract CompoundNFT is ERC20Vault {
    event Supply(address, uint256);
    event Redeem(address, uint256);
    event Borrow(address, uint256);
    event Repay(address, uint256);

    function supplyEth(address payable _cEtherContract) public payable onlyOwner {
        // Create a reference to the corresponding cToken contract
        CToken cToken = CToken(_cEtherContract);
        cToken.mint{value: msg.value}();
        emit Supply(address(0), msg.value);
    }

    function supplyErc20(
        address _erc20Contract,
        address _cErc20Contract,
        uint256 _numTokensToSupply
    ) public onlyOwner {
        // Create a reference to the underlying asset contract, like DAI.
        IERC20 underlying = IERC20(_erc20Contract);
        // Create a reference to the corresponding cToken contract, like cDAI
        CToken cToken = CToken(_cErc20Contract);
        // Approve transfer on the ERC20 contract
        underlying.approve(_cErc20Contract, _numTokensToSupply);
        
        // Mint cTokens
        cToken.mint(_numTokensToSupply);
        emit Supply(_erc20Contract, _numTokensToSupply);
    }

    function redeemCTokens(
        uint256 amount,
        bool redeemType,
        address _cTokenContract
    ) public onlyOwner {
        // Create a reference to the corresponding cToken contract, like cDAI
        CToken cToken = CToken(_cTokenContract);
        uint256 redeemResult;
        if (redeemType == true) {
            // Retrieve your asset based on a cToken amount
            redeemResult = cToken.redeem(amount);
        } else {
            // Retrieve your asset based on an amount of the asset
            redeemResult = cToken.redeemUnderlying(amount);
        }

        emit Redeem(_cTokenContract, amount);
    }

    function borrowErc20(
        address payable _cEtherAddress,
        address _comptrollerAddress,
        address _cTokenAddress,
        uint _underlyingDecimals,
        uint256 numUnderlyingToBorrow
    ) public payable onlyOwner {
        CToken cEth = CToken(_cEtherAddress);
        Comptroller comptroller = Comptroller(_comptrollerAddress);
        CToken cToken = CToken(_cTokenAddress);

        // Supply ETH as collateral, get cETH in return
        cEth.mint{value: msg.value}();

        // Enter the ETH market so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cEtherAddress;
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed.");
        }

        // Get my account's total liquidity value in Compound
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(address(this));
        if (error != 0) {
            revert("Comptroller.getAccountLiquidity failed.");
        }
        require(shortfall == 0, "CompoundNFT: Account underwater");
        require(liquidity > 0, "CompoundNFT: Account has excess collateral");

        // Borrow, check the underlying balance for this contract's address
        cToken.borrow(numUnderlyingToBorrow * 10** _underlyingDecimals);
        emit Borrow(_cTokenAddress, numUnderlyingToBorrow);
    }

    function repayBorrowedERC20(
        address _erc20Address,
        address _cErc20Address,
        uint256 amount
    ) public onlyOwner {
        IERC20 underlying = IERC20(_erc20Address);
        underlying.approve(_cErc20Address, amount);
        emit Repay(_erc20Address, amount);
    }

    function borrowEth(
        address payable _cEtherAddress,
        address _comptrollerAddress,
        address _cTokenAddress,
        address _underlyingAddress,
        uint256 _underlyingToSupplyAsCollateral,
        uint256 numWeiToBorrow
    ) public onlyOwner {
        CToken cEth = CToken(_cEtherAddress);
        Comptroller comptroller = Comptroller(_comptrollerAddress);
        CToken cToken = CToken(_cTokenAddress);
        IERC20 underlying = IERC20(_underlyingAddress);

        // Approve transfer of underlying
        underlying.approve(_cTokenAddress, _underlyingToSupplyAsCollateral);

        // Supply underlying as collateral, get cToken in return
        uint256 error = cToken.mint(_underlyingToSupplyAsCollateral);
        require(error == 0, "CToken.mint Error");

        // Enter the market so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cTokenAddress;
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed.");
        }

        // Get my account's total liquidity value in Compound
        (uint256 error2, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(address(this));
        if (error2 != 0) {
            revert("Comptroller.getAccountLiquidity failed.");
        }
        require(shortfall == 0, "CompoundNFT: Account underwater");
        require(liquidity > 0, "CompoundNFT: Account has excess collateral");

        // Borrow, then check the underlying balance for this contract's address
        cEth.borrow(numWeiToBorrow);
        emit Borrow(address(0), numWeiToBorrow);
    }

    function repayBorrowedETH(address _cEtherAddress, uint256 amount) public onlyOwner {
        CToken cEth = CToken(_cEtherAddress);
        cEth.repayBorrow{value: amount}();
        emit Repay(address(0), amount);
    }

}
