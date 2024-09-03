// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../lib/forge-std/src/Test.sol";
import "../contracts/RewardManager.sol";
import "../contracts/lib/SafeMath.sol";
import "../contracts/interfaces/IEvolution.sol";
import "../contracts/interfaces/IWorldID.sol";
import "../contracts/Evolution.sol";

contract RewardManagerTest is Test {
    using SafeMath for uint256;

    RewardManager rewardManager;
    Evolution evolutionToken;
    IWorldID worldId;

    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);
    address approver = address(4);
    address unauthorizedAddress = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;

    function setUp() public {
        vm.startPrank(owner);
        uint8 totalLevels = 5;
        evolutionToken = new Evolution(1000000);

        // worldId = IWorldID(address(new MockWorldID()));
        rewardManager = new RewardManager(
            address(evolutionToken),
            5, // total levels
            IWorldID(address(1)),
            "appId",
            "actionId",
            "actionId"
        );

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

        evolutionToken.setRewardManager(address(rewardManager));

        rewardManager.transferOwnership(owner);
        vm.stopPrank();
    }

    function testInitialSetup() public view {
        assertEq(rewardManager.totalLevels(), 5);
        assertEq(rewardManager.EvolutionToken(), address(evolutionToken));
        assertEq(rewardManager.contractDeploymentTimestamp(), block.timestamp);
    }

    function testSetEvolutionCriteria() public {
        uint8[] memory levels = new uint8[](4);
        levels[0] = 0;
        levels[1] = 1;
        levels[2] = 2;
        levels[3] = 3;

        RewardManager.EvolutionCriteria[]
            memory criteria = new RewardManager.EvolutionCriteria[](4);
        criteria[0] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 1,
            minOrbReferralsPerLevelToEvolve: 0,
            tokensToBurnPerLevelToEvolve: 10000
        });
        criteria[1] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 10,
            minOrbReferralsPerLevelToEvolve: 1,
            tokensToBurnPerLevelToEvolve: 100000
        });
        criteria[2] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 15,
            minOrbReferralsPerLevelToEvolve: 10,
            tokensToBurnPerLevelToEvolve: 1000000
        });
        criteria[3] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 20,
            minOrbReferralsPerLevelToEvolve: 100,
            tokensToBurnPerLevelToEvolve: 10000000
        });

        vm.prank(owner);
        rewardManager.setEvolutionCriteria(levels, criteria);

        assertEq(rewardManager.getMinReferralsRequiredPerLevelToEvolve(0), 1);
        assertEq(rewardManager.getMinReferralsRequiredPerLevelToEvolve(1), 10);
        assertEq(rewardManager.getMinReferralsRequiredPerLevelToEvolve(2), 15);
        assertEq(rewardManager.getMinReferralsRequiredPerLevelToEvolve(3), 20);

        assertEq(rewardManager.getMinOrbReferralsCount(0), 0);
        assertEq(rewardManager.getMinOrbReferralsCount(1), 1);
        assertEq(rewardManager.getMinOrbReferralsCount(2), 10);
        assertEq(rewardManager.getMinOrbReferralsCount(3), 100);

        assertEq(rewardManager.getMinTokenAmountToBurn(0), 10000);
        assertEq(rewardManager.getMinTokenAmountToBurn(1), 100000);
        assertEq(rewardManager.getMinTokenAmountToBurn(2), 1000000);
        assertEq(rewardManager.getMinTokenAmountToBurn(3), 10000000);
    }

    function testSetEvolutionCriteria_OnlyOwner() public {
        uint8[] memory levels = new uint8[](1);
        levels[0] = 0;

        RewardManager.EvolutionCriteria[]
            memory criteria = new RewardManager.EvolutionCriteria[](1);
        criteria[0] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 5,
            minOrbReferralsPerLevelToEvolve: 2,
            tokensToBurnPerLevelToEvolve: 100
        });
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                unauthorizedAddress
            )
        );
        rewardManager.setEvolutionCriteria(levels, criteria);
    }

    function testSetEvolutionCriteria_InvalidLength() public {
        uint8[] memory levels = new uint8[](1);
        levels[0] = 0;

        RewardManager.EvolutionCriteria[]
            memory criteria = new RewardManager.EvolutionCriteria[](1);
        criteria[0] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 5,
            minOrbReferralsPerLevelToEvolve: 2,
            tokensToBurnPerLevelToEvolve: 100
        });
        vm.prank(owner);
        vm.expectRevert(RewardManager.InvalidParamLength.selector);
        rewardManager.setEvolutionCriteria(levels, criteria);
    }

    function testSetEvolutionCriteria_InvalidLevel() public {
        uint8[] memory levels = new uint8[](4);
        levels[0] = 0;
        levels[1] = 1;
        levels[2] = 2;
        levels[3] = 6;

        RewardManager.EvolutionCriteria[]
            memory criteria = new RewardManager.EvolutionCriteria[](4);
        criteria[0] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 5,
            minOrbReferralsPerLevelToEvolve: 0,
            tokensToBurnPerLevelToEvolve: 10000
        });
        criteria[1] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 10,
            minOrbReferralsPerLevelToEvolve: 1,
            tokensToBurnPerLevelToEvolve: 100000
        });
        criteria[2] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 15,
            minOrbReferralsPerLevelToEvolve: 10,
            tokensToBurnPerLevelToEvolve: 1000000
        });
        criteria[3] = RewardManager.EvolutionCriteria({
            minReferralsRequiredPerLevelToEvolve: 20,
            minOrbReferralsPerLevelToEvolve: 100,
            tokensToBurnPerLevelToEvolve: 10000000
        });

        vm.prank(owner);
        vm.expectRevert(RewardManager.InvalidLevel.selector);
        rewardManager.setEvolutionCriteria(levels, criteria);
    }

    function testSetEvolutionRewardPercentagePerLevel() public {
        uint32[] memory levels = new uint32[](5);
        levels[0] = 1;
        levels[1] = 10;
        levels[2] = 100;
        levels[3] = 1000;
        levels[4] = 10000;

        vm.prank(owner);
        rewardManager.setEvolutionRewardPercentagePerLevel(levels);

        assertEq(rewardManager.evolutionRewardPercentagePerLevel(0), 1);
        assertEq(rewardManager.evolutionRewardPercentagePerLevel(1), 10);
        assertEq(rewardManager.evolutionRewardPercentagePerLevel(2), 100);
        assertEq(rewardManager.evolutionRewardPercentagePerLevel(3), 1000);
        assertEq(rewardManager.evolutionRewardPercentagePerLevel(4), 10000);
    }

    function testSetEvolutionRewardPercentagePerLevel_OnlyOwner() public {
        uint32[] memory levels = new uint32[](1);
        levels[0] = 100;
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                unauthorizedAddress
            )
        );
        rewardManager.setEvolutionRewardPercentagePerLevel(levels);
    }

    function testSetEvolutionRewardPercentagePerLevel_InvalidLength() public {
        uint32[] memory levels = new uint32[](1);
        levels[0] = 100;
        vm.prank(owner);
        vm.expectRevert(RewardManager.InvalidParamLength.selector);
        rewardManager.setEvolutionRewardPercentagePerLevel(levels);
    }

    function testSetApproverAddress() public {
        vm.prank(owner);
        rewardManager.setApproverAddress(approver);
        assertEq(rewardManager.approver(), approver);
    }

    function testSetApproverAddress_OnlyOwner() public {
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                unauthorizedAddress
            )
        );
        rewardManager.setApproverAddress(approver);
    }

    function testSetApproverAddress_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert(RewardManager.InvalidAddress.selector);
        rewardManager.setApproverAddress(address(0));
    }

    function testAllowDeviceLevelUsers() public {
        // Test that only the owner can call allowDeviceLevelUsers
        vm.prank(owner);
        rewardManager.allowDeviceLevelUsers(true);
        assertEq(rewardManager.isDeviceLevelUsersAllowed(), true);

        vm.prank(owner);
        rewardManager.allowDeviceLevelUsers(false);
        assertEq(rewardManager.isDeviceLevelUsersAllowed(), false);
    }

    function testAllowDeviceLevelUsers_OnlyOwner() public {
        // Test that non-owner cannot call allowDeviceLevelUsers
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                unauthorizedAddress
            )
        );
        rewardManager.allowDeviceLevelUsers(true);
    }

    function testRegisterWithDevice() public {
        (address alice, uint256 key) = makeAddrAndKey("approver_key");
        vm.prank(owner);
        rewardManager.setApproverAddress(alice);

        bytes32 commitment = rewardManager.makeUserRegistrationCommitment(
            RewardManager.VerificationType.Device,
            user2,
            block.timestamp
        );

        (uint8 v, bytes32 r, bytes32 s) = _signCommitment(commitment, key);
        // need to set elevolution revard perse
        testSetEvolutionRewardPercentagePerLevel();
        uint256 noOfUsersInFirstLevel = rewardManager
            .getNoOfRegisterUserInLevel(0);

        _registerWithDevice(user2, address(0));
        assertEq(
            rewardManager.getNoOfRegisterUserInLevel(0),
            noOfUsersInFirstLevel + 1
        );

        noOfUsersInFirstLevel = rewardManager.getNoOfRegisterUserInLevel(0);
        vm.prank(user1);
        rewardManager.registerWithDevice(user2, block.timestamp, v, r, s);

        (
            RewardManager.VerificationType verificationType,
            ,
            ,
            ,
            ,
            ,

        ) = rewardManager.users(user1);

        assertTrue(rewardManager.isUserRegistered(user1));
        assertEq(rewardManager.getReferrerAddress(user1), user2);
        assertEq(
            rewardManager.getNoOfRegisterUserInLevel(0),
            noOfUsersInFirstLevel + 1
        );
        assertEq(
            uint8(verificationType),
            uint8(RewardManager.VerificationType.Device)
        );
    }

    function testRegisterWithDevice_InvalidSigner() public {
        (, uint256 key) = makeAddrAndKey("approver_key");
        vm.prank(owner);
        rewardManager.setApproverAddress(approver);

        bytes32 commitment = rewardManager.makeUserRegistrationCommitment(
            RewardManager.VerificationType.Device,
            user2,
            block.timestamp
        );

        (uint8 v, bytes32 r, bytes32 s) = _signCommitment(commitment, key);

        vm.prank(user1);
        vm.expectRevert(RewardManager.InvalidSigner.selector);
        rewardManager.registerWithDevice(user2, block.timestamp, v, r, s);
    }

    function testRegisterWithOrb() public {
        uint256 nullifierHash = 1;

        vm.prank(user1);
        uint16[] memory proof = new uint16[](1);
        proof[0] = 0;
        vm.expectRevert();
        rewardManager.registerWithOrb(
            user2,
            user1,
            1,
            nullifierHash,
            [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ]
        );

        assertFalse(rewardManager.isUserRegistered(user1));
        assertFalse(rewardManager.registerNullifierHashes(nullifierHash));
        (
            RewardManager.VerificationType verificationType,
            ,
            ,
            ,
            ,
            ,

        ) = rewardManager.users(user1);
        assertEq(
            uint8(verificationType),
            uint8(RewardManager.VerificationType.None)
        );
    }

    function testFailRegisterWithOrb_DuplicateNullifier() public {
        uint256 nullifierHash = 1;

        vm.prank(user1);
        rewardManager.registerWithOrb(
            user2,
            user1,
            1,
            nullifierHash,
            [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ]
        );

        vm.prank(user1);
        rewardManager.registerWithOrb(
            user2,
            user1,
            1,
            nullifierHash,
            [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ]
        );
    }

    function testEvolve_IneligibleToEvolve() public {
        testSetEvolutionCriteria();

        vm.startPrank(user1);
        // Set user's referrals and token balance to make them eligible
        // rewardManager.users(user1).numOrbReferrals = 2;
        // rewardManager.users(user1).numDeviceReferrals = 3;

        // Set token allowance
        evolutionToken.approve(address(rewardManager), 100);

        // Evolve
        vm.expectRevert(RewardManager.IneligibleToEvolve.selector);
        rewardManager.evolve();

        // Check evolved level
        (, uint8 evolutionLevel, , , , , ) = rewardManager.users(user1);
        assertEq(evolutionLevel, 0);

        vm.stopPrank();
    }

    function testEvolve_InsufficientAllowance() public {
        testSetEvolutionCriteria();

        // Set user's referrals and token balance to make them eligible
        // rewardManager.users(user1).numOrbReferrals = 2;
        // rewardManager.users(user1).numDeviceReferrals = 3;

        // Set token allowance
        evolutionToken.approve(address(rewardManager), 100);

        // Evolve
        _openTrading(1 ether);
        evolutionToken.transfer(user2, 100 * 10 ** evolutionToken.decimals());
        testRegisterWithDevice();
        vm.startPrank(user2);

        vm.expectRevert(RewardManager.InsufficientAllowance.selector);
        rewardManager.evolve();

        // Check evolved level
        (, uint8 evolutionLevel, , , , , ) = rewardManager.users(user2);
        assertEq(evolutionLevel, 0);

        vm.stopPrank();
    }

    function testEvolve() public {
        testSetEvolutionCriteria();

        // Set user's referrals and token balance to make them eligible
        // rewardManager.users(user1).numOrbReferrals = 2;
        // rewardManager.users(user1).numDeviceReferrals = 3;

        // Set token allowance
        evolutionToken.approve(address(rewardManager), 100);

        // Evolve
        _openTrading(1 ether);
        evolutionToken.transfer(user2, 100 * 10 ** evolutionToken.decimals());
        testRegisterWithDevice();
        vm.startPrank(user2);

        vm.expectRevert(RewardManager.InsufficientAllowance.selector);
        rewardManager.evolve();

        evolutionToken.approve(
            address(evolutionToken),
            100000 * 10 ** evolutionToken.decimals()
        );
        evolutionToken.approve(
            address(rewardManager),
            100000 * 10 ** evolutionToken.decimals()
        );
        // uint256 balanceBefore = evolutionToken.balanceOf(user2);
        rewardManager.evolve();
        // uint256 balanceAfter = evolutionToken.balanceOf(user2);

        // Check evolved level
        (, uint8 evolutionLevel, , , , , ) = rewardManager.users(user2);
        assertEq(evolutionLevel, 1);
        // assertEq((balanceBefore-100000),balanceAfter);
        assertEq(rewardManager.getUserEvolutionLevel(user2), 1);

        vm.stopPrank();
    }

    // function testTransfer() public {
    //     _openTrading(1 ether);
    //     vm.startPrank(owner);
    //     uint256 ownerBalance = evolutionToken.balanceOf(owner);
    //     evolutionToken.transfer(user1, (ownerBalance * 10) / 100);
    //     vm.stopPrank();
    //     assertEq(evolutionToken.balanceOf(user1), (ownerBalance * 10) / 100);
    //     assertEq(evolutionToken.balanceOf(owner), (ownerBalance * 90) / 100);
    // }

    function testClaimReward() public {
        testEvolve();
        // Simulate claim process
        // Assuming user1 is already registered and eligible for rewards

        // Simulate reward distribution
        vm.startPrank(address(evolutionToken));
        rewardManager.distributeRewards(1000);

        vm.stopPrank();
        // Claim rewards
        // vm.expectRevert(RewardManager.ZeroReward.selector);
        // vm.expectRevert("Trading is not active.");
        // rewardManager.claimReward();

        // deal(owner, 100 ether);
        // vm.expectRevert("Trading is already open");
        // _openTrading(1 ether);

        // vm.prank(user2);
        // rewardManager.claimReward();

        // Check claimable rewards
        (, , , , uint256 claimableRewards, , ) = rewardManager.users(user1);
        assertEq(claimableRewards, 0);
    }

    function testFailClaimReward_ZeroReward() public {
        vm.prank(user1);
        rewardManager.claimReward();
    }

    function testGetRewardAmount() public view {
        // Test data
        uint8 level = 1;
        uint256 lastRewardPoints = 50;
        uint256 claimableRewards = 100;

        // Expected reward calculation
        // Reward per user at level 1 is 0 (initialized in RewardManager)
        // Reward amount = 0 (rewardPerUser) + 100 (claimableRewards) - 50 (lastRewardPoints)
        uint256 expectedRewardAmount = 50;

        // Call the function and assert the result
        uint256 actualRewardAmount = rewardManager.getRewardAmount(
            level,
            lastRewardPoints,
            claimableRewards
        );
        assertEq(actualRewardAmount, expectedRewardAmount);
    }

    function testGetRewardAmountWithZeroLastRewardPoints() public view {
        uint8 level = 2;
        uint256 lastRewardPoints = 0;
        uint256 claimableRewards = 150;

        // Expected reward calculation
        // Reward per user at level 2 is 0 (initialized in RewardManager)
        // Reward amount = 0 (rewardPerUser) + 150 (claimableRewards) - 0 (lastRewardPoints)
        uint256 expectedRewardAmount = 150;

        uint256 actualRewardAmount = rewardManager.getRewardAmount(
            level,
            lastRewardPoints,
            claimableRewards
        );
        assertEq(actualRewardAmount, expectedRewardAmount);
    }

    function testGetRewardAmountWithNegativeResult() public {
        uint8 level = 0;
        uint256 lastRewardPoints = 150;
        uint256 claimableRewards = 25;

        // Expected reward calculation
        // Reward per user at level 0 is 100 (initialized in RewardManager)
        // Reward amount = 100 (rewardPerUser) + 25 (claimableRewards) - 150 (lastRewardPoints)
        uint256 expectedRewardAmount = 0; // Since the subtraction might lead to negative, it should ideally be capped at 0 or handled in logic

        vm.expectRevert();
        uint256 actualRewardAmount = rewardManager.getRewardAmount(
            level,
            lastRewardPoints,
            claimableRewards
        );
        assertEq(actualRewardAmount, expectedRewardAmount);
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

    function _openTrading(uint256 ethValue) internal {
        deal(owner, ethValue);
        vm.startPrank(owner);
        evolutionToken.transfer(
            address(evolutionToken),
            100 * 10 ** evolutionToken.decimals()
        );
        evolutionToken.transfer(
            address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496),
            100 * 10 ** evolutionToken.decimals()
        );
        evolutionToken.openTrading{value: ethValue}();
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
}

// contract MockEvolution is Evolution {
//     using SafeMath for uint256;

//     mapping(address => uint256) balances;
//     mapping(address => mapping(address => uint256)) allowances;

//     function balanceOf(address account) external view returns (uint256) {
//         return balances[account];
//     }

// function transfer(
//     address recipient,
//     uint256 amount
// ) external returns (bool) {
//     require(balances[msg.sender] >= amount, "Insufficient balance");
//     balances[msg.sender] = balances[msg.sender].sub(amount);
//     balances[recipient] = balances[recipient].add(amount);
//     return true;
// }

//     function approve(address spender, uint256 amount) external returns (bool) {
//         allowances[msg.sender][spender] = amount;
//         return true;
//     }

//     function burnFrom(address account, uint256 amount) external {
//         require(balances[account] >= amount, "Insufficient balance to burn");
//         balances[account] = balances[account].sub(amount);
//     }

//     function allowance(
//         address owner,
//         address spender
//     ) external view returns (uint256) {
//         return allowances[owner][spender];
//     }

//     function mint(address account, uint256 amount) external {
//         balances[account] = balances[account].add(amount);
//     }
// }

// contract MockWorldID is IWorldID {
//     function verifyProof(
//         uint256 root,
//         uint256 nullifierHash,
//         uint256[8] calldata proof
//     ) external pure returns (bool) {
//         return true;
//     }
// }
