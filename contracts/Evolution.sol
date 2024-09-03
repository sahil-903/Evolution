// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./lib/SafeMath.sol";
import "./lib/Address.sol";
import "./interfaces/IRewardManager.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract Evolution is ERC20, Ownable {
    using SafeMath for *;
    using Address for address;

    // UniswapV2 Router Address
    IUniswapV2Router02 public uniswapV2Router;

    // Pair Address
    address public uniswapV2Pair;

    address public ownerAddress;

    // TODO: Need to check while deploy
    address public constant ROUTER_ADDRESS =
        address(0xb4A560Deb7BF1ba86cAAB74b2f425E7Bd11CF75d);

    uint256 public firstBlock;
    bool public tradingOpen;

    // Tax Percentage
    uint256 public constant initialTransferTax = 25;
    uint256 public constant rewardDistributionTaxForVerified = 5;
    uint256 public constant verifiedUserTaxToReferrer = 3;
    uint256 public constant rewardDistributionTaxForUnverified = 8;
    uint256 public constant unverifiedUserTaxToOwner = 4;

    // TODO: testnet
    // uint256 public constant reduceTransferTaxAt = 2;
    uint256 public constant reduceTransferTaxAt = 10;

    uint256 public buyCount = 0;

    // Reward Manger
    IRewardManager public rewardManager;

    // Fee Exclusion Addresses
    mapping(address => bool) public whitelistAddressForFee;

    // Events
    event RewardManagerAddrChanged(address rewardManager);
    event WhitelistAddressForFee(address[] userAddresss, bool[] values);

    constructor(
        uint256 _totalSupply
    ) ERC20("Evolution", "EVL") Ownable(_msgSender()) {
        _mint(_msgSender(), (_totalSupply * 10 ** decimals()));
        ownerAddress = _msgSender();
        whitelistAddressForFee[owner()] = true;
        whitelistAddressForFee[address(this)] = true;
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        _safeTransfer(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _safeTransfer(from, to, value);
        return true;
    }

    function burnFrom(address _account, uint256 _value) external {
        _spendAllowance(_account, _msgSender(), _value);
        _burn(_account, _value);
    }

    function _safeTransfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        if (
            from != owner() &&
            to != owner() &&
            to != address(0) &&
            to != address(0xdead)
        ) {
            // If trading is not yet active
            if (!tradingOpen) {
                require(
                    whitelistAddressForFee[from] || whitelistAddressForFee[to],
                    "Trading is not active."
                );
            }

            // buying the token
            if (
                from == uniswapV2Pair &&
                to != address(uniswapV2Router) &&
                !whitelistAddressForFee[to] &&
                !whitelistAddressForFee[from]
            ) {
                // contract cannot buy in first 3 blocks
                if (firstBlock + 3 > block.number) {
                    require(!to.isContract());
                }
                buyCount++;
            }

            // calculating and transfer tax amount
            if (
                from != owner() &&
                to != owner() &&
                !whitelistAddressForFee[to] &&
                !whitelistAddressForFee[from]
            ) {
                // first buy limit is not exceeded
                if (buyCount <= reduceTransferTaxAt) {
                    taxAmount = amount.mul(initialTransferTax).div(100);
                    _transfer(from, address(rewardManager), taxAmount);
                    rewardManager.distributeRewards(taxAmount);
                } else {
                    // checking if user is registered on RewardManager contract, and calculating tax based on that.
                    if (rewardManager.isUserRegistered(to)) {
                        address referrer = rewardManager.getReferrerAddress(to);

                        // Calculating tax referral amount
                        uint256 taxAmountToReferrer = amount
                            .mul(verifiedUserTaxToReferrer)
                            .div(100);

                        // Transferring tax referral amount
                        if (taxAmountToReferrer > 0) {
                            _transfer(from, referrer, taxAmountToReferrer);
                        }

                        // Calculating tax amount for evolution reward
                        uint256 taxAmountToDistribute = amount
                            .mul(rewardDistributionTaxForVerified)
                            .div(100);

                        // Distributing tax amount for evolution reward
                        if (taxAmountToDistribute > 0) {
                            _transfer(
                                from,
                                address(rewardManager),
                                taxAmountToDistribute
                            );
                            rewardManager.distributeRewards(
                                taxAmountToDistribute
                            );
                        }
                        // Total tax amount used
                        taxAmount = taxAmountToDistribute + taxAmountToReferrer;
                    } else {
                        // Calculating tax amount for unverified user to transfer to owner
                        uint256 taxAmountToOwner = amount
                            .mul(unverifiedUserTaxToOwner)
                            .div(100);

                        // Transferring tax amount of unverified user to owner.
                        _transfer(from, ownerAddress, taxAmountToOwner);

                        // Calculating tax amount for unverified user to distribute as evolution rewards
                        uint256 taxAmountToDistribute = amount
                            .mul(rewardDistributionTaxForUnverified)
                            .div(100);

                        // Distributing tax amount of unverified user to distribute.
                        _transfer(
                            from,
                            address(rewardManager),
                            taxAmountToDistribute
                        );
                        rewardManager.distributeRewards(taxAmountToDistribute);

                        // Total tax amount used
                        taxAmount = taxAmountToDistribute + taxAmountToOwner;
                    }
                }
            }
        }

        // transferring the net amount to the user.
        _transfer(from, to, amount.sub(taxAmount));
    }

    // This function will set the addres for rewardManager
    function setRewardManager(
        address _rewardManger
    ) external virtual onlyOwner {
        require(_rewardManger != address(0), "Invalid rewardManager address");

        require(_rewardManger.isContract(), "RewardManger should be contract");
        rewardManager = IRewardManager(_rewardManger);
        whitelistAddressForFee[_rewardManger] = true;
        emit RewardManagerAddrChanged(_rewardManger);
    }

    // set whitelist addresses
    function setWhitelistAddressForFeeBatch(
        address[] memory userAddresss,
        bool[] memory values
    ) external onlyOwner {
        require(userAddresss.length == values.length, "Length Mismatch");
        for (uint256 itr = 0; itr < userAddresss.length; itr++) {
            whitelistAddressForFee[userAddresss[itr]] = values[itr];
        }
        emit WhitelistAddressForFee(userAddresss, values);
    }

    // Adds the liquidity
    function openTrading() external payable onlyOwner {
        require(!tradingOpen, "Trading is already open");

        uniswapV2Router = IUniswapV2Router02(ROUTER_ADDRESS);
        _approve(address(this), address(uniswapV2Router), totalSupply());

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );
        ERC20(uniswapV2Pair).approve(
            address(uniswapV2Router),
            type(uint256).max
        );

        tradingOpen = true;
        firstBlock = block.number;
    }
}
