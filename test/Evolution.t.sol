// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../lib/forge-std/src/Test.sol";
import "../contracts/Evolution.sol";
import "../contracts/RewardManager.sol";
import "../contracts/Bot.sol";
import "../contracts/interfaces/IRewardManager.sol";
import "../contracts/interfaces/IWorldID.sol";
import "../contracts/interfaces/IUniswapV2Router02.sol";
import "../contracts/interfaces/IUniswapV2Factory.sol";
import "../lib/forge-std/src/console.sol";

interface IUniswapV2Router is IUniswapV2Router02 {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

contract EvolutionTokenTest is Test {
    Evolution public evolutionToken;

    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address user3 = address(0x4);

    address public weth;

    RewardManager public rewardManager;

    Bot public tradingBot;

    IUniswapV2Router public uniswapRouter =
        IUniswapV2Router(address(0xA73CA83290eED32141FdB76045E583aFDBE63CdD));

    IUniswapV2Factory public factory;

    uint256 tokenTotalSupply = 1000000;
    uint8 totalLevels = 5;
    address worldIdRouter = address(0x10);
    string appId = "appId";
    string actionId = "actionId";

    uint256 weiValue = 10 ** 18;

    function setUp() public {
        // Initialize the contract with a total supply of 1 million tokens
        vm.startPrank(owner);
        evolutionToken = new Evolution(tokenTotalSupply);
        rewardManager = new RewardManager(
            address(evolutionToken),
            totalLevels,
            IWorldID(worldIdRouter),
            appId,
            actionId,
            actionId
        );

        tradingBot = new Bot();

        uint8[] memory levels = new uint8[](totalLevels - 1);
        levels[0] = 0;
        levels[1] = 1;
        levels[2] = 2;
        levels[3] = 3;

        uint32[] memory evolutionRewardPercentage = new uint32[](totalLevels);

        evolutionRewardPercentage[0] = uint32(10);
        evolutionRewardPercentage[1] = uint32(1000);
        evolutionRewardPercentage[2] = uint32(10000);
        evolutionRewardPercentage[3] = uint32(100000);
        evolutionRewardPercentage[4] = uint32(1000000);

        RewardManager.EvolutionCriteria[]
            memory data = new RewardManager.EvolutionCriteria[](
                totalLevels - 1
            );
        data[0] = RewardManager.EvolutionCriteria(10, 0, 10000);
        data[1] = RewardManager.EvolutionCriteria(100, 1, 100000);
        data[2] = RewardManager.EvolutionCriteria(1000, 10, 1000000);
        data[3] = RewardManager.EvolutionCriteria(10000, 100, 10000000);

        rewardManager.setEvolutionRewardPercentagePerLevel(
            evolutionRewardPercentage
        );
        rewardManager.setEvolutionCriteria(levels, data);
        factory = IUniswapV2Factory(uniswapRouter.factory());
        weth = uniswapRouter.WETH();
        evolutionToken.setRewardManager(address(rewardManager));
        vm.stopPrank();
    }

    function testInitialSetup() public view {
        assertEq(evolutionToken.name(), "EvolutionToken");
        assertEq(evolutionToken.symbol(), "Evolution");
        assertEq(evolutionToken.owner(), owner);
        assertEq(
            evolutionToken.balanceOf(owner),
            tokenTotalSupply * 10 ** evolutionToken.decimals()
        );
        assertEq(
            evolutionToken.totalSupply(),
            tokenTotalSupply * 10 ** evolutionToken.decimals()
        );
        assertTrue(evolutionToken.whitelistAddressForFee(owner));
        assertTrue(evolutionToken.whitelistAddressForFee(address(evolutionToken)));
        assertEq(evolutionToken.tradingOpen(), false);
        assertEq(address(evolutionToken.rewardManager()), address(rewardManager));
    }

    function testBalanceOf() public view {
        assertEq(evolutionToken.balanceOf(owner), tokenTotalSupply * weiValue);
    }

    function testApproveAndAllowance() public {
        vm.prank(owner);
        evolutionToken.approve(user1, (tokenTotalSupply * weiValue * 10) / 100);
        assertEq(
            evolutionToken.allowance(owner, user1),
            (tokenTotalSupply * weiValue * 10) / 100
        );
    }

    function testChangedAllowance() public {
        vm.startPrank(owner);
        evolutionToken.approve(user1, (100 * weiValue * 10) / 100);
        assertEq(evolutionToken.allowance(owner, user1), (100 * weiValue * 10) / 100);

        evolutionToken.approve(user1, (2 * 100 * weiValue * 10) / 100);
        assertEq(
            evolutionToken.allowance(owner, user1),
            (2 * 100 * weiValue * 10) / 100
        );

        evolutionToken.approve(user1, (100 * weiValue * 10) / (2 * 100));
        assertEq(
            evolutionToken.allowance(owner, user1),
            (100 * weiValue * 10) / (2 * 100)
        );
        vm.stopPrank();
    }

    function testTransfer() public {
        _openTrading(1 ether);
        vm.startPrank(owner);
        uint256 ownerBalance = evolutionToken.balanceOf(owner);
        evolutionToken.transfer(user1, (ownerBalance * 10) / 100);
        vm.stopPrank();
        assertEq(evolutionToken.balanceOf(user1), (ownerBalance * 10) / 100);
        assertEq(evolutionToken.balanceOf(owner), (ownerBalance * 90) / 100);
    }

    function testTransferFullAmount() public {
        _openTrading(1 ether);
        vm.startPrank(owner);
        uint256 ownerBalance = evolutionToken.balanceOf(owner);
        evolutionToken.transfer(user1, ownerBalance);
        vm.stopPrank();
        assertEq(evolutionToken.balanceOf(user1), ownerBalance);
        assertEq(evolutionToken.balanceOf(owner), 0);
    }

    function testTransferFrom() public {
        _openTrading(1 ether);
        vm.startPrank(owner);
        uint256 ownerBalance = evolutionToken.balanceOf(owner);
        evolutionToken.approve(user1, (ownerBalance * 10) / 100);
        vm.stopPrank();

        vm.prank(user1);
        evolutionToken.transferFrom(owner, user1, (ownerBalance * 10) / 100);

        assertEq(evolutionToken.balanceOf(user1), (ownerBalance * 10) / 100);
        assertEq(evolutionToken.balanceOf(owner), (ownerBalance * 90) / 100);
        assertEq(evolutionToken.allowance(owner, user1), 0);
    }

    function testTransferFailInsufficientBalance() public {
        _openTrading(1 ether);
        vm.prank(user1);
        vm.expectRevert();
        evolutionToken.transfer(user2, 1000 * weiValue);
    }

    function testTransferFailToZeroAddress() public {
        _openTrading(1 ether);
        vm.prank(owner);
        vm.expectRevert();
        evolutionToken.transfer(address(0), 1000 * weiValue);
    }

    function testTransferFailToDeadAddressBeforeOpenTrading() public {
        vm.prank(user1);
        vm.expectRevert();
        evolutionToken.transfer(address(0xdead), 1000 * weiValue);
    }

    function testTransferFailWithZeroAmount() public {
        _openTrading(1 ether);
        vm.prank(owner);
        vm.expectRevert();
        evolutionToken.transfer(user1, 0);
    }

    function testTransferFromFailInsufficientBalance() public {
        _openTrading(1 ether);
        vm.prank(owner);
        evolutionToken.approve(user1, 100 * weiValue);

        vm.prank(user1);
        vm.expectRevert();
        evolutionToken.transferFrom(owner, user1, 2 * tokenTotalSupply * weiValue);
    }

    function testTransferFromFailInsufficientAllowance() public {
        _openTrading(1 ether);
        vm.prank(owner);
        evolutionToken.approve(user1, 100 * weiValue);

        vm.prank(user1);
        vm.expectRevert();
        evolutionToken.transferFrom(owner, user1, 200 * weiValue);
    }

    function testFailTransferFromZeroAddress() public {
        _openTrading(1 ether);
        vm.prank(user1);
        evolutionToken.transferFrom(address(0), user1, 1e18);
    }

    function testFailTransferFromDeadAddressBeforeOpenTrading() public {
        vm.prank(user1);
        evolutionToken.transferFrom(address(0xdead), user1, 1e18);
    }

    function testFailTransferFromToZeroAddress() public {
        _openTrading(1 ether);
        vm.startPrank(owner);
        uint256 ownerBalance = evolutionToken.balanceOf(owner);
        evolutionToken.approve(user1, (ownerBalance * 10) / 100);
        vm.stopPrank();
        vm.prank(user1);
        evolutionToken.transferFrom(owner, address(0), (ownerBalance * 10) / 100);
    }

    function testFailTransferBeforeTradingOpen() public {
        // Should fail because trading is not open and addresses are not whitelisted
        vm.prank(user1);
        evolutionToken.transfer(user2, 100 * 10 ** evolutionToken.decimals());
    }

    function testTransferFromOwnerBeforeTradingOpen() public {
        vm.startPrank(owner);
        evolutionToken.transfer(user1, weiValue);
        vm.stopPrank();
    }

    function testTransferToOwnerBeforeTradingOpen() public {
        vm.startPrank(owner);
        evolutionToken.transfer(user1, weiValue);
        vm.stopPrank();

        vm.startPrank(user1);
        evolutionToken.transfer(owner, weiValue);
        vm.stopPrank();
    }

    function testTransferFromWhitelistedAddressBeforeTradingOpen() public {
        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = user2;

        bool[] memory allow = new bool[](2);
        allow[0] = true;
        allow[1] = false;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addresses, allow);
        evolutionToken.transfer(user1, weiValue);
        vm.stopPrank();

        vm.startPrank(user1);
        evolutionToken.transfer(user2, weiValue);
        vm.stopPrank();
    }

    function testTransferToWhitelistedAddressBeforeTradingOpen() public {
        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = user2;

        bool[] memory allow = new bool[](2);
        allow[0] = true;
        allow[1] = false;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addresses, allow);
        evolutionToken.transfer(user2, weiValue);
        vm.stopPrank();

        vm.startPrank(user2);
        evolutionToken.transfer(user1, weiValue);
        vm.stopPrank();
    }

    function testTransferAfterTradingOpen() public {
        _openTrading(1 ether);
        uint256 transferAmt = weiValue;
        uint256 ownerBalance = evolutionToken.balanceOf(owner);
        vm.startPrank(owner);
        evolutionToken.transfer(user1, transferAmt);
        vm.stopPrank();

        assertEq(evolutionToken.balanceOf(owner), ownerBalance - transferAmt);
        assertEq(evolutionToken.balanceOf(user1), transferAmt);
        assertEq(evolutionToken.balanceOf(user2), 0);

        vm.startPrank(owner);
        evolutionToken.transfer(user2, transferAmt);
        vm.stopPrank();

        assertEq(evolutionToken.balanceOf(owner), ownerBalance - (2 * transferAmt));
        assertEq(evolutionToken.balanceOf(user1), transferAmt);
        assertEq(evolutionToken.balanceOf(user2), transferAmt);

        vm.prank(user1);
        evolutionToken.transfer(user2, transferAmt);

        assertEq(evolutionToken.balanceOf(owner), ownerBalance - (2 * transferAmt));
        assertEq(evolutionToken.balanceOf(user1), 0);
        assertEq(evolutionToken.balanceOf(user2), (transferAmt * 175) / 100);
    }

    function testFailBurnFromInsufficientBalance() public {
        vm.startPrank(owner);
        evolutionToken.transfer(user1, 10 * weiValue);
        vm.stopPrank();

        vm.prank(user1);
        evolutionToken.burnFrom(user1, 50 * weiValue);
    }

    function testFailBurnFromInsufficientAllowance() public {
        vm.startPrank(owner);
        evolutionToken.transfer(user1, 10 * weiValue);
        vm.stopPrank();

        vm.prank(user2);
        evolutionToken.approve(user1, 2 * weiValue);

        vm.prank(user1);
        evolutionToken.burnFrom(user1, 5 * weiValue);
    }

    function testBurnFrom() public {
        vm.startPrank(owner);
        evolutionToken.transfer(user2, 10 * weiValue);
        vm.stopPrank();

        vm.prank(user2);
        evolutionToken.approve(user1, 5 * weiValue);

        vm.prank(user1);
        evolutionToken.burnFrom(user2, 5 * weiValue);

        assertEq(evolutionToken.balanceOf(user2), 5 * weiValue);
    }

    function testBurnFromReduceAllowance() public {
        vm.startPrank(owner);
        evolutionToken.transfer(user2, 10 * weiValue);
        vm.stopPrank();

        vm.prank(user2);
        evolutionToken.approve(user1, 10 * weiValue);

        vm.prank(user1);
        evolutionToken.burnFrom(user2, 5 * weiValue);

        assertEq(evolutionToken.allowance(user2, user1), 5 * weiValue);

        assertEq(evolutionToken.balanceOf(user2), 5 * weiValue);
    }

    function testFailTransferOwnershipByNonOwner() public {
        vm.prank(user1);
        evolutionToken.transferOwnership(user1);
    }

    function testTransferOwnership() public {
        vm.prank(owner);
        evolutionToken.transferOwnership(user1);
        assertEq(evolutionToken.owner(), user1);
    }

    function testFailRenounceOwnershipByNonUser() public {
        vm.prank(user1);
        evolutionToken.renounceOwnership();
    }

    function testRenounceOwnership() public {
        vm.prank(owner);
        evolutionToken.renounceOwnership();
        assertEq(evolutionToken.owner(), address(0));
    }

    function testFailWhitelistAddressForFeeByNonOwner() public {
        address[] memory addrs = new address[](2);
        addrs[0] = user1;
        addrs[1] = user2;
        bool[] memory values = new bool[](2);
        values[0] = true;
        values[1] = false;

        vm.startPrank(user1);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        vm.stopPrank();
    }

    function testFailWhitelistAddressForFeeByWhitelistAddress() public {
        address[] memory addrs = new address[](1);
        addrs[0] = user1;
        bool[] memory values = new bool[](1);
        values[0] = true;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        vm.stopPrank();

        addrs[0] = user2;
        vm.startPrank(user1);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        vm.stopPrank();
    }

    function testFailWhitelistAddressForFeeInvalidLength() public {
        address[] memory addrs = new address[](2);
        addrs[0] = user1;
        addrs[1] = user2;
        bool[] memory values = new bool[](1);
        values[0] = true;

        vm.startPrank(user1);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        vm.stopPrank();
    }

    function testWhitelistAddressForFeeBatch() public {
        address[] memory addrs = new address[](2);
        addrs[0] = user1;
        addrs[1] = user2;
        bool[] memory values = new bool[](2);
        values[0] = true;
        values[1] = false;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        vm.stopPrank();

        assertTrue(evolutionToken.whitelistAddressForFee(user1));
        assertFalse(evolutionToken.whitelistAddressForFee(user2));
    }

    function testWhitelistAddressForFeeBatchReverse() public {
        address[] memory addrs = new address[](2);
        addrs[0] = user1;
        addrs[1] = user2;
        bool[] memory values = new bool[](2);
        values[0] = true;
        values[1] = false;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        vm.stopPrank();

        assertTrue(evolutionToken.whitelistAddressForFee(user1));
        assertFalse(evolutionToken.whitelistAddressForFee(user2));

        address[] memory addrs1 = new address[](2);
        addrs1[0] = user1;
        addrs1[1] = user2;
        bool[] memory values1 = new bool[](2);
        values1[0] = false;
        values1[1] = true;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs1, values1);
        vm.stopPrank();

        assertFalse(evolutionToken.whitelistAddressForFee(user1));
        assertTrue(evolutionToken.whitelistAddressForFee(user2));
    }

    function testWhitelistAddressForFeeBatchNotByOwner() public {
        address[] memory addrs = new address[](2);
        addrs[0] = user1;
        addrs[1] = user2;
        bool[] memory values = new bool[](2);
        values[0] = true;
        values[1] = false;

        vm.expectRevert();
        vm.startPrank(user1);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        vm.stopPrank();
    }

    function testFailSetRewardManagerWithZeroAddress() public {
        vm.prank(owner);
        evolutionToken.setRewardManager(address(0));
    }

    function testFailSetRewardManagerWithNonContractAddress() public {
        vm.prank(owner);
        evolutionToken.setRewardManager(user1);
    }

    function testFailSetRewardManagerByNonOwner() public {
        vm.prank(user1);
        evolutionToken.setRewardManager(user1);
    }

    function testSetRewardManager() public {
        vm.prank(owner);
        evolutionToken.setRewardManager(address(rewardManager));
        assertEq(address(evolutionToken.rewardManager()), address(rewardManager));
    }

    function testFailAddLiquidityByNonOwnerOnUniswap() public {
        uint256 tokenLiquidityAmount = 100 * weiValue;
        deal(user1, 1 ether);
        vm.startPrank(owner);
        evolutionToken.transfer(user1, tokenLiquidityAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        evolutionToken.approve(address(uniswapRouter), tokenLiquidityAmount);
        uniswapRouter.addLiquidityETH{value: 1 ether}(
            address(evolutionToken),
            tokenLiquidityAmount,
            0,
            0,
            user1,
            block.timestamp
        );
        vm.stopPrank();
    }

    function testAddLiquidityByWhitelistedAddressOnUniswap() public {
        uint256 tokenLiquidityAmount = 100 * weiValue;
        deal(user1, 1 ether);

        address[] memory addrs = new address[](1);
        addrs[0] = user1;
        bool[] memory values = new bool[](1);
        values[0] = true;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        evolutionToken.transfer(user1, tokenLiquidityAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        evolutionToken.approve(address(uniswapRouter), tokenLiquidityAmount);
        uniswapRouter.addLiquidityETH{value: 1 ether}(
            address(evolutionToken),
            tokenLiquidityAmount,
            0,
            0,
            user1,
            block.timestamp
        );
        vm.stopPrank();
    }

    function testAddLiquidityByOwnerOnUniswap() public {
        uint256 tokenLiquidityAmount = 100 * weiValue;
        deal(owner, 1 ether);

        vm.startPrank(owner);
        evolutionToken.approve(address(uniswapRouter), tokenLiquidityAmount);
        uniswapRouter.addLiquidityETH{value: 1 ether}(
            address(evolutionToken),
            tokenLiquidityAmount,
            0,
            0,
            owner,
            block.timestamp
        );
        vm.stopPrank();
    }

    function testFailSwapAfterAddLiquidityOnUniswap() public {
        uint256 tokenLiquidityAmount = 100 * weiValue;
        deal(user2, 1 ether);

        vm.startPrank(owner);
        evolutionToken.approve(address(uniswapRouter), tokenLiquidityAmount);
        uniswapRouter.addLiquidityETH{value: 1 ether}(
            address(evolutionToken),
            tokenLiquidityAmount,
            0,
            0,
            user1,
            block.timestamp
        );
        vm.stopPrank();

        vm.startPrank(user2);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(evolutionToken);
        uniswapRouter.swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            user2,
            block.timestamp
        );
        vm.stopPrank();
    }

    function testSwapToWhitelistAddressAfterAddLiquidityOnUniswap() public {
        uint256 tokenLiquidityAmount = 100 * weiValue;
        deal(user1, 2 ether);

        address[] memory addrs = new address[](1);
        addrs[0] = user1;
        bool[] memory values = new bool[](1);
        values[0] = true;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addrs, values);
        evolutionToken.transfer(user1, tokenLiquidityAmount);
        vm.stopPrank();

        vm.startPrank(user1);
        evolutionToken.approve(address(uniswapRouter), tokenLiquidityAmount);
        uniswapRouter.addLiquidityETH{value: 1 ether}(
            address(evolutionToken),
            tokenLiquidityAmount,
            0,
            0,
            user1,
            block.timestamp
        );

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(evolutionToken);
        uniswapRouter.swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            user1,
            block.timestamp
        );
        vm.stopPrank();
    }

    function testFailOpenTradingByNonOwner() public {
        deal(user1, 1 ether);
        vm.startPrank(owner);
        evolutionToken.transfer(user1, 100 * weiValue);
        vm.stopPrank();
        vm.startPrank(user1);
        evolutionToken.transfer(address(evolutionToken), 100 * weiValue);
        evolutionToken.openTrading{value: 1 ether}();
        vm.stopPrank();
    }

    function testFailOpenTradingByWhitelistAddress() public {
        deal(user1, 1 ether);

        address[] memory addresses = new address[](1);
        addresses[0] = user1;

        bool[] memory allow = new bool[](1);
        allow[0] = true;

        vm.startPrank(owner);
        evolutionToken.setWhitelistAddressForFeeBatch(addresses, allow);
        evolutionToken.transfer(user1, 100 * weiValue);
        vm.stopPrank();

        vm.startPrank(user1);
        evolutionToken.transfer(address(evolutionToken), 100 * weiValue);
        evolutionToken.openTrading{value: 1 ether}();
        vm.stopPrank();
    }

    function testOpenTrading() public {
        deal(owner, 1 ether);
        vm.startPrank(owner);
        evolutionToken.transfer(address(evolutionToken), 100 * 10 ** evolutionToken.decimals());
        evolutionToken.openTrading{value: 1 ether}();
        vm.stopPrank();
        assertTrue(evolutionToken.tradingOpen());
        assertEq(uint256(evolutionToken.firstBlock()), block.number);
        assertTrue(evolutionToken.uniswapV2Pair() != address(0));
    }

    function testFailOpenTradingInsufficientBalance() public {
        deal(owner, 1 ether);
        vm.startPrank(owner);
        assertEq(uint256(evolutionToken.balanceOf(address(evolutionToken))), uint256(0));
        evolutionToken.openTrading{value: 1 ether}();
        vm.stopPrank();
        assertTrue(evolutionToken.tradingOpen());
        assertEq(uint256(evolutionToken.firstBlock()), block.number);
        assertTrue(evolutionToken.uniswapV2Pair() != address(0));
    }

    function testFailOpenTradingTwice() public {
        deal(owner, 1 ether);
        vm.startPrank(owner);
        evolutionToken.transfer(address(evolutionToken), 100 * 10 ** evolutionToken.decimals());
        evolutionToken.openTrading{value: 1 ether}();
        evolutionToken.transfer(address(evolutionToken), 100 * 10 ** evolutionToken.decimals());
        evolutionToken.openTrading{value: 1 ether}();
        vm.stopPrank();
        assertTrue(evolutionToken.tradingOpen());
        assertEq(uint256(evolutionToken.firstBlock()), block.number);
        assertTrue(evolutionToken.uniswapV2Pair() != address(0));
    }

    function testSwapAfterOpenTrading() public {
        _openTrading(1 ether);
        _swapETHToEvolution(user1, 1 ether);
        uint256 evolutionTokenBalanceAfterSwap = evolutionToken.balanceOf(user1);
        _swapEvolutionToETH(user1, evolutionTokenBalanceAfterSwap);
    }

    function testFailSwapAfter1BlocksFromOpenTrading() public {
        _openTrading(1 ether);
        vm.roll(block.number + 1);
        deal(address(tradingBot), 1 ether);
        tradingBot.swap{value: 0.1 ether}(
            address(evolutionToken),
            0,
            address(tradingBot),
            block.timestamp
        );
    }

    function testFailSwapAfter2BlocksFromOpenTrading() public {
        _openTrading(1 ether);
        vm.roll(block.number + 2);
        deal(address(tradingBot), 1 ether);
        tradingBot.swap{value: 0.1 ether}(
            address(evolutionToken),
            0,
            address(tradingBot),
            block.timestamp
        );
    }

    function testFailSwapInNextBlockFromOpenTrading() public {
        _openTrading(1 ether);
        deal(address(tradingBot), 1 ether);
        tradingBot.swap{value: 0.1 ether}(
            address(evolutionToken),
            0,
            address(tradingBot),
            block.timestamp
        );
    }

    function testSwapAfter3BlocksFromOpenTrading() public {
        _openTrading(1 ether);
        vm.roll(block.number + 3);
        deal(address(tradingBot), 1 ether);
        tradingBot.swap{value: 0.1 ether}(
            address(evolutionToken),
            0,
            address(tradingBot),
            block.timestamp
        );
    }

    function testBuyingInitialTransferTax() public {
        deal(owner, 100 ether);
        _openTrading(100 ether);

        vm.startPrank(user1);

        // 10 times to reach reduceAtCount
        for (uint8 i = 0; i < 10; i++) {
            uint256 rewardManagerInitialbalance = evolutionToken.balanceOf(
                address(rewardManager)
            );
            uint256 balanceBeforeSwap = evolutionToken.balanceOf(user1);

            uint256 outputAmount = _getAmountOut(
                weth,
                address(evolutionToken),
                0.75 ether
            );

            uint256 outputAmountWithoutTax = _getAmountOut(
                weth,
                address(evolutionToken),
                1 ether
            );

            _swapETHToEvolution(user1, 1 ether);

            uint256 balanceAfterSwap = evolutionToken.balanceOf(user1);

            uint256 rewardManagerFinalbalance = evolutionToken.balanceOf(
                address(rewardManager)
            );

            assertTrue(
                (outputAmount * 99) / 100 < balanceAfterSwap - balanceBeforeSwap
            );
            assertTrue(
                balanceAfterSwap - balanceBeforeSwap <
                    (outputAmount * 101) / 100
            );

            assertTrue(
                rewardManagerFinalbalance - rewardManagerInitialbalance >
                    ((outputAmountWithoutTax - outputAmount) * 99) / 100
            );
            assertTrue(
                rewardManagerFinalbalance - rewardManagerInitialbalance <
                    ((outputAmountWithoutTax - outputAmount) * 101) / 100
            );
        }

        vm.stopPrank();
    }

    function testBuyingTransferTaxAfterThresholdForUnVerifiedUser() public {
        _finishInitialTransferTaxLimit();
        uint256 initialRewardBalance = evolutionToken.balanceOf(
            address(rewardManager)
        );

        uint256 initialOwnerBalance = evolutionToken.balanceOf(owner);
        vm.startPrank(user1);

        uint256 balanceBefore11thSwap = evolutionToken.balanceOf(user1);

        uint256 outputAmountFor11thSwap = _getAmountOut(
            weth,
            address(evolutionToken),
            0.88 ether
        );

        uint256 outputAmountFor11thSwapWithoutTax = _getAmountOut(
            weth,
            address(evolutionToken),
            1 ether
        );

        _swapETHToEvolution(user1, 1 ether);

        uint256 balanceAfter11thSwap = evolutionToken.balanceOf(user1);

        uint256 finalRewardBalance = evolutionToken.balanceOf(address(rewardManager));
        uint256 finalOwnerBalance = evolutionToken.balanceOf(owner);
        assertTrue(
            (outputAmountFor11thSwap * 99) / 100 <
                balanceAfter11thSwap - balanceBefore11thSwap
        );

        assertTrue(
            balanceAfter11thSwap - balanceBefore11thSwap <
                (outputAmountFor11thSwap * 101) / 100
        );

        assertTrue(
            finalRewardBalance - initialRewardBalance >
                (((outputAmountFor11thSwapWithoutTax * 8) / 100) * 99) / 100
        );
        assertTrue(
            finalRewardBalance - initialRewardBalance <
                (((outputAmountFor11thSwapWithoutTax * 8) / 100) * 101) / 100
        );

        assertTrue(
            finalOwnerBalance - initialOwnerBalance >
                (((outputAmountFor11thSwapWithoutTax * 4) / 100) * 99) / 100
        );
        assertTrue(
            finalOwnerBalance - initialOwnerBalance <
                (((outputAmountFor11thSwapWithoutTax * 4) / 100) * 101) / 100
        );
        vm.stopPrank();
    }

    function testBuyingTransferTaxAfterThresholdForVerifiedUser() public {
        _finishInitialTransferTaxLimit();
        _registerWithDevice(owner, address(0));
        _registerWithDevice(user1, owner);
        vm.startPrank(user1);

        address referrer = rewardManager.getReferrerAddress(user1);
        assertEq(referrer, owner);
        uint256 initialRewardBalance = evolutionToken.balanceOf(
            address(rewardManager)
        );
        uint256 referrerRewardInitialBalance = evolutionToken.balanceOf(referrer);
        uint256 balanceBefore11thSwap = evolutionToken.balanceOf(user1);

        uint256 outputAmountFor11thSwap = _getAmountOut(
            weth,
            address(evolutionToken),
            0.92 ether
        );

        uint256 outputAmountFor11thSwapWithoutTax = _getAmountOut(
            weth,
            address(evolutionToken),
            1 ether
        );

        _swapETHToEvolution(user1, 1 ether);

        uint256 balanceAfter11thSwap = evolutionToken.balanceOf(user1);

        uint256 referrerRewardFinalBalance = evolutionToken.balanceOf(referrer);

        uint256 finalRewardBalance = evolutionToken.balanceOf(address(rewardManager));

        assertTrue(
            (outputAmountFor11thSwap * 99) / 100 <
                balanceAfter11thSwap - balanceBefore11thSwap
        );

        assertTrue(
            balanceAfter11thSwap - balanceBefore11thSwap <
                (outputAmountFor11thSwap * 101) / 100
        );

        assertTrue(
            ((((outputAmountFor11thSwapWithoutTax) * 3) / 100) * 99) / 100 <
                referrerRewardFinalBalance - referrerRewardInitialBalance
        );

        assertTrue(
            referrerRewardFinalBalance - referrerRewardInitialBalance <
                ((((outputAmountFor11thSwapWithoutTax) * 3) / 100) * 101) / 100
        );
        assertTrue(
            finalRewardBalance - initialRewardBalance >
                (((outputAmountFor11thSwapWithoutTax * 5) / 100) * 99) / 100
        );
        assertTrue(
            finalRewardBalance - initialRewardBalance <
                (((outputAmountFor11thSwapWithoutTax * 5) / 100) * 101) / 100
        );

        vm.stopPrank();
    }

    function testSellingInitialTransferTax() public {
        deal(owner, 100 ether);
        _openTrading(100 ether);

        vm.startPrank(user1);

        uint256 balanceBeforeBuy = evolutionToken.balanceOf(user1);

        uint256 buyOutputAmount = _getAmountOut(
            weth,
            address(evolutionToken),
            0.75 ether
        );

        _swapETHToEvolution(user1, 1 ether);

        uint256 balanceAfterBuy = evolutionToken.balanceOf(user1);

        assertTrue(
            (buyOutputAmount * 99) / 100 < balanceAfterBuy - balanceBeforeBuy
        );
        assertTrue(
            balanceAfterBuy - balanceBeforeBuy < (buyOutputAmount * 101) / 100
        );

        uint256 balanceBeforeSell = user1.balance;

        uint256 rewardManagerInitialBalance = evolutionToken.balanceOf(
            address(rewardManager)
        );

        uint256 sellOutputAmount = _getAmountOut(
            address(evolutionToken),
            weth,
            (evolutionToken.balanceOf(user1) * 75) / 100
        );

        uint256 sellOutputAmountWithoutTax = _getAmountOut(
            address(evolutionToken),
            weth,
            evolutionToken.balanceOf(user1)
        );

        _swapEvolutionToETH(user1, evolutionToken.balanceOf(user1));

        uint256 balanceAfterSell = user1.balance;

        uint256 rewardManagerFinalBalance = evolutionToken.balanceOf(
            address(rewardManager)
        );

        assertTrue(
            (sellOutputAmount * 99) / 100 < balanceAfterSell - balanceBeforeSell
        );
        assertTrue(
            balanceAfterSell - balanceBeforeSell <
                (sellOutputAmount * 101) / 100
        );

        assertTrue(
            rewardManagerFinalBalance - rewardManagerInitialBalance >
                ((sellOutputAmountWithoutTax - sellOutputAmount) * 99) / 100
        );
        assertTrue(
            rewardManagerFinalBalance - rewardManagerInitialBalance <
                ((sellOutputAmountWithoutTax - sellOutputAmount) * 101) / 100
        );

        vm.stopPrank();
    }

    function testSellingTransferTaxAfterThreshold() public {
        _finishInitialTransferTaxLimit();

        _swapETHToEvolution(user1, 1 ether);

        uint256 initialRewardBalance = evolutionToken.balanceOf(
            address(rewardManager)
        );

        uint256 initialOwnerBalance = evolutionToken.balanceOf(owner);

        vm.startPrank(user1);

        uint256 userBalance = evolutionToken.balanceOf(user1);

        uint256 balanceBeforeSell = user1.balance;

        uint256 sellOutputAmount = _getAmountOut(
            address(evolutionToken),
            weth,
            (userBalance * 88) / 100
        );

        _swapEvolutionToETH(user1, userBalance);

        uint256 balanceAfterSell = user1.balance;
        
        uint256 finalRewardBalance = evolutionToken.balanceOf(address(rewardManager));
        
        uint256 finalOwnerBalance = evolutionToken.balanceOf(owner);
        
        assertTrue(
            (sellOutputAmount * 99) / 100 < balanceAfterSell - balanceBeforeSell
        );

        assertTrue(
            balanceAfterSell - balanceBeforeSell <
                (sellOutputAmount * 101) / 100
        );

        assertTrue(
            finalRewardBalance - initialRewardBalance >
                (((userBalance * 8) / 100) * 99) / 100
        );

        assertTrue(
            finalRewardBalance - initialRewardBalance <
                (((userBalance * 8) / 100) * 101) / 100
        );

        assertTrue(
            finalOwnerBalance - initialOwnerBalance >
                (userBalance * 4 * 99) / 10000
        );
        assertTrue(
            finalOwnerBalance - initialOwnerBalance <
                (userBalance * 4 * 101) / 10000
        );

        vm.stopPrank();
    }


    function _openTrading(uint256 ethValue) internal {
        deal(owner, ethValue);
        vm.startPrank(owner);
        evolutionToken.transfer(address(evolutionToken), 100 * 10 ** evolutionToken.decimals());
        evolutionToken.openTrading{value: ethValue}();
        vm.stopPrank();
    }

    function _swapETHToEvolution(address sender, uint256 ethValue) internal {
        vm.startPrank(sender);
        deal(sender, ethValue);
        uint256 initialBalance = evolutionToken.balanceOf(sender);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(evolutionToken);
        uniswapRouter.swapExactETHForTokens{value: ethValue}(
            0,
            path,
            sender,
            block.timestamp
        );
        uint256 updatedBalance = evolutionToken.balanceOf(sender);
        assertTrue(updatedBalance > initialBalance);
        vm.stopPrank();
    }

    function _swapEvolutionToETH(address sender, uint256 tokenValue) internal {
        vm.startPrank(sender);
        uint256 initialBalance = evolutionToken.balanceOf(sender);
        address[] memory path = new address[](2);
        path[0] = address(evolutionToken);
        path[1] = weth;
        evolutionToken.approve(address(uniswapRouter), type(uint256).max);
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenValue,
            0,
            path,
            sender,
            block.timestamp
        );
        uint256 updatedBalance = evolutionToken.balanceOf(sender);
        assertTrue(updatedBalance < initialBalance);
        vm.stopPrank();
    }

    function _getAmountOut(
        address token1,
        address token2,
        uint256 amountIn
    ) internal view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;

        uint256[] memory amountsOut;
        amountsOut = uniswapRouter.getAmountsOut(amountIn, path);
        return amountsOut[amountsOut.length - 1];
    }

    function _finishInitialTransferTaxLimit() internal {
        deal(owner, 100 ether);
        _openTrading(100 ether);

        vm.startPrank(user1);

        for (uint8 i = 0; i < 10; i++) {
            uint256 balanceBeforeSwap = evolutionToken.balanceOf(user1);

            uint256 outputAmount = _getAmountOut(
                weth,
                address(evolutionToken),
                1 ether
            );

            uint256 finalOutputAmountAfterTaxDeduction = (outputAmount * 75) /
                100;

            _swapETHToEvolution(user1, 1 ether);

            uint256 balanceAfterSwap = evolutionToken.balanceOf(user1);

            assertTrue(
                (finalOutputAmountAfterTaxDeduction * 99) / 100 <
                    balanceAfterSwap - balanceBeforeSwap
            );
            assertTrue(
                balanceAfterSwap - balanceBeforeSwap <
                    (finalOutputAmountAfterTaxDeduction * 101) / 100
            );
        }

        vm.stopPrank();
    }

    function _registerWithDevice(address _account, address _referrer) public {
        (address alice, uint256 key) = makeAddrAndKey("approver_key");
        vm.prank(owner);
        rewardManager.setApproverAddress(alice);

        bytes32 commitment = rewardManager.makeUserRegistrationCommitment(
            RewardManager.VerificationType.Device,
            _referrer,
            block.timestamp
        );

        (uint8 v, bytes32 r, bytes32 s) = _signCommitment(commitment, key);

        vm.prank(_account);
        rewardManager.registerWithDevice(_referrer, block.timestamp, v, r, s);
    }

    function _signCommitment(
        bytes32 commitment,
        uint256 key
    ) internal pure returns (uint8, bytes32, bytes32) {
        bytes32 digest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", commitment)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return (v, r, s);
    }
}
