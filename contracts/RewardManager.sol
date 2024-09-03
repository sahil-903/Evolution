// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./lib/SafeMath.sol";
import "./lib/Address.sol";
import "./lib/ByteHasher.sol";
import "./interfaces/IEvolution.sol";
import "./interfaces/IWorldID.sol";

contract RewardManager is Ownable {
    using SafeMath for *;
    using Address for address;
    using ByteHasher for bytes;

    // WorldId Verification Levels
    enum VerificationType {
        None,
        Device,
        Orb
    }

    // Manage data for each level
    struct Level {
        uint256 noOfUsers; // No of users in that level
        uint256 rewardPerUser; // RewardPoints per user in that level
        EvolutionCriteria evolutionCriteriaPerLevel; // Criteria required per level to evolve
    }

    // Manage data for each user
    struct User {
        VerificationType verificationType; // User's WorldId Verification Type
        uint8 evolutionLevel; // User's Evolution Level
        uint256 numOrbReferrals; // User's orb referrals
        uint256 numDeviceReferrals; // User's device referrals
        uint256 claimableRewards; // User's claimable rewards
        uint256 lastRewardPoints; // User's reward points when last claimed or evolved
        address referrerAddress; // User's referrer address
    }

    struct EvolutionCriteria {
        uint256 minReferralsRequiredPerLevelToEvolve; // Minimum Overall Referrals required per level to evolve
        uint256 minOrbReferralsPerLevelToEvolve; // Minimum Orb Referrals Required Per Level To Evolve
        uint256 tokensToBurnPerLevelToEvolve; // Minimum Required Tokens to burn per level To evolve
    }

    // Evolution Percentage Per Level To Claim Rewards
    uint32[] public evolutionRewardPercentagePerLevel;

    mapping(uint8 => Level) public levels;
    mapping(address => User) public users;
    mapping(uint256 => bool) public registerNullifierHashes;
    mapping(uint256 => bool) public upgradeNullifierHashes;

    // Total levels to evolve for the users
    uint8 public totalLevels;

    // Ratio to increase the Orb Referral Count per year required to evolve
    uint8 public constant orbReferralGrowthRate = 2;

    // Ratio to decrease the EVolution Burn Amount per year required to evolve
    uint8 public constant tokenBurnDecreaseRate = 2;

    // Total Weight of all the registered users.
    uint256 public totalUserWeight;

    // For increasing the orb referral count or decreasing the token burn amount yearly
    uint256 public contractDeploymentTimestamp;

    // World-Id Unique Registration Hash
    uint256 public immutable registerExternalNullifier;

    // World-Id Unique Upgrade to Orb Hash
    uint256 public immutable upgradeExternalNullifier;

    // TODO: Testnet
    // uint256 public constant oneYearTimestamp = 1800;
    uint256 public constant oneYearTimestamp = 31556926;

    // Evolution Token Address
    address public immutable EvolutionToken;

    // Commitment Approver Address
    address public approver;

    // To stop the device level users to register in the future.
    bool public isDeviceLevelUsersAllowed = true;

    // World Id router instance
    IWorldID public immutable worldId;

    // Events
    event Registered(
        address indexed user,
        address indexed referrer,
        VerificationType verificationType
    );
    event Upgraded(address indexed user);
    event RewardClaimed(address indexed user, uint256 claimAmount);
    event Evolved(
        address indexed user,
        uint256 evolutionLevel,
        uint256 totalBurnAmountToEvolve
    );
    event RewardsDistributed(uint8 level, uint256 rewardPerUser);
    event ApproverAddrChanged(address indexed approver);
    event Verified(uint256 nullifierHash);

    error DuplicateNullifier(uint256 nullifierHash);
    error OnlyRewardToken();
    error InvalidParamLength();
    error InvalidLevel();
    error InvalidAddress();
    error InsufficientAllowance();
    error IneligibleToEvolve();
    error ZeroReward();
    error MaxLevelReached();
    error InvalidSigner();
    error AlreadyRegistered();
    error InvalidVerification();
    error OnlyOrbVerifiedUsers();
    error UserNotRegistered();

    // modifiers
    modifier onlyRewardToken() {
        if (msg.sender != EvolutionToken) {
            revert OnlyRewardToken();
        }
        _;
    }

    constructor(
        address _evlToken,
        uint8 _totalLevels,
        IWorldID _worldId,
        string memory _appId,
        string memory _registerActionId,
        string memory _upgradeActionId
    ) Ownable(msg.sender) {
        EvolutionToken = _evlToken;
        totalLevels = _totalLevels;
        contractDeploymentTimestamp = block.timestamp;
        worldId = _worldId;

        registerExternalNullifier = abi
            .encodePacked(
                abi.encodePacked(_appId).hashToField(),
                _registerActionId
            )
            .hashToField();

        upgradeExternalNullifier = abi
            .encodePacked(
                abi.encodePacked(_appId).hashToField(),
                _upgradeActionId
            )
            .hashToField();
    }

    // Set evolution criteria for each level
    function setEvolutionCriteria(
        uint8[] calldata _levels,
        EvolutionCriteria[] calldata _criteria
    ) external onlyOwner {
        if (
            _levels.length != _criteria.length ||
            _levels.length != totalLevels - 1
        ) {
            revert InvalidParamLength();
        }
        for (uint8 level = 0; level < _levels.length; level++) {
            if (_levels[level] >= totalLevels) {
                revert InvalidLevel();
            }
            levels[_levels[level]].evolutionCriteriaPerLevel = _criteria[level];
        }
    }

    // Setting evolution reward percentage per level for each level.
    function setEvolutionRewardPercentagePerLevel(
        uint32[] calldata _evolutionRewardPercentagePerLevel
    ) external onlyOwner {
        if (_evolutionRewardPercentagePerLevel.length != totalLevels) {
            revert InvalidParamLength();
        }
        evolutionRewardPercentagePerLevel = _evolutionRewardPercentagePerLevel;
    }

    // Set commitment approver address. Approver address should not be zero address or contract address
    function setApproverAddress(address _approver) external onlyOwner {
        if (_approver == address(0) || _approver.isContract()) {
            revert InvalidAddress();
        }
        approver = _approver;
        emit ApproverAddrChanged(_approver);
    }

    // Allowing device level users to register.
    function allowDeviceLevelUsers(bool _shouldAllow) external onlyOwner {
        isDeviceLevelUsersAllowed = _shouldAllow;
    }

    // Registration for device level users.
    function registerWithDevice(
        address _referrer,
        uint256 _timestamp,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        {
            bytes32 commitment = makeUserRegistrationCommitment(
                VerificationType.Device,
                _referrer,
                _timestamp
            );

            _verifyCommitment(commitment, v, r, s);
        }
        _registerUser(msg.sender, _referrer, VerificationType.Device);
    }

    // Registration for orb level users that verifies the proof on-chain.
    function registerWithOrb(
        address _referrer,
        address signal,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external {
        // First, we make sure this person hasn't done this before
        if (registerNullifierHashes[nullifierHash]) {
            revert DuplicateNullifier(nullifierHash);
        }

        // We now verify the provided proof is valid and the user is verified by World ID
        worldId.verifyProof(
            root,
            1,
            abi.encodePacked(signal).hashToField(),
            nullifierHash,
            registerExternalNullifier,
            proof
        );

        // We now record the user has done this, so they can't do it again (proof of uniqueness)
        registerNullifierHashes[nullifierHash] = true;

        // Registering the user on the contract with Orb Verification Type after verifying the proofs
        _registerUser(msg.sender, _referrer, VerificationType.Orb);

        // Make sure to emit some kind of event afterwards!
        emit Verified(nullifierHash);
    }

    // Updating the user to ORB verified level.
    function upgradeToOrb(
        address signal,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external {
        // First, we make sure this person hasn't done this before
        if (upgradeNullifierHashes[nullifierHash]) {
            revert DuplicateNullifier(nullifierHash);
        }

        // We now verify the provided proof is valid and the user is verified by World ID
        worldId.verifyProof(
            root,
            1,
            abi.encodePacked(signal).hashToField(),
            nullifierHash,
            upgradeExternalNullifier,
            proof
        );

        // We now record the user has done this, so they can't do it again (proof of uniqueness)
        upgradeNullifierHashes[nullifierHash] = true;

        address _referrer = getReferrerAddress(msg.sender);

        // Upgrading the user on the contract with Orb Verification Type after verifying the proofs
        _upgradeUser(msg.sender, _referrer);

        // Make sure to emit some kind of event afterwards!
        emit Verified(nullifierHash);

        emit Registered(msg.sender, _referrer, VerificationType.Orb);
    }

    // Distributing rewards to the users.
    function distributeRewards(uint256 _taxAmount) external onlyRewardToken {
        for (uint8 level = 0; level < totalLevels; level++) {
            if (levels[level].noOfUsers > 0) {
                // Calculating per user Evolution reward amount and setting the amount as rewardPerUser for each level.
                uint rewardForLevel = _taxAmount.mul((level.add(1)).mul(10)).div(100);
                levels[level].rewardPerUser = rewardForLevel;
                emit RewardsDistributed(level, levels[level].rewardPerUser);
            }
        }

        uint256[] memory initialRewards = new uint256[](totalLevels);
        uint256[] memory adjustedRewards = new uint256[](totalLevels);

        // Calculate initial rewards based on percentage distribution
        for (uint256 level = 0; level < totalLevels; level++) {
            // L1 -> 10%, L2 -> 20%, L3 -> 30%, L4 -> 40% 
            initialRewards[level] = (_taxAmount.mul(level.add(1)).mul(10)).div(100);
        }

        // Calculate total users
        uint256 totalUsers = 0;
        for (uint8 level = 0; level < totalLevels; level++) {
            totalUsers += levels[level].noOfUsers;
        }

        uint256 totalAdjustedRewards = 0;
        // Adjust rewards based on user presence
        for (uint8 level = 0; level < totalLevels; level++) {
            if (levels[level].noOfUsers > 0) {
                adjustedRewards[level] = initialRewards[level];
                totalAdjustedRewards += adjustedRewards[level];
            }
        }

        // Redistribute remaining rewards
        uint256 remainingReward = _taxAmount - totalAdjustedRewards;
        if (totalUsers > 0) {
            for (uint8 level = 0; level < totalLevels; level++) {
                if (levels[level].noOfUsers > 0) {
                    adjustedRewards[level] += (remainingReward * levels[level].noOfUsers) / totalUsers;
                }
            }
        }

        // Calculate final rewards per user per level
        uint256[] memory finalRewardsPerUser = new uint256[](totalLevels);
        for (uint8 level = 0; level < totalLevels; level++) {
            if (levels[level].noOfUsers > 0) {
                finalRewardsPerUser[level] = adjustedRewards[level] / levels[level].noOfUsers;
                levels[level].rewardPerUser = finalRewardsPerUser[level];
            }
            emit RewardsDistributed(level, levels[level].rewardPerUser);
        }
    }

    function evolve() external {
        // Getting user's eigibility level.
        uint256 totalBurnAmountToEvolve = getEvolutionBurnAmount(msg.sender);

        // Check if user is eligible for the level he passed.
        if (totalBurnAmountToEvolve == 0) {
            revert IneligibleToEvolve();
        }

        // For burning tokens to evolve the user.
        if (
            IERC20(EvolutionToken).allowance(msg.sender, EvolutionToken) <
            totalBurnAmountToEvolve
        ) {
            revert InsufficientAllowance();
        }

        User memory user = users[msg.sender];

        // Calculating new pending claimable reward amount of the user
        uint256 rewardAmount = getRewardAmount(
            user.evolutionLevel,
            user.lastRewardPoints,
            user.claimableRewards
        );

        users[msg.sender].claimableRewards = rewardAmount;

        // Updating the totalUserWeight = totalUserWeight - (EvolutionRewardPercentage of user's current level) + (EvolutionRewardPercentage of user's new level)
        totalUserWeight = totalUserWeight
            .sub(evolutionRewardPercentagePerLevel[user.evolutionLevel])
            .add(evolutionRewardPercentagePerLevel[user.evolutionLevel + 1]);

        // Setting the user's last reward points as last rewardPerUser of new level.
        users[msg.sender].lastRewardPoints = levels[user.evolutionLevel + 1]
            .rewardPerUser;

        // Increasing the no of users in new level .
        levels[user.evolutionLevel].noOfUsers = levels[user.evolutionLevel]
            .noOfUsers
            .sub(1);

        // Decreasing the no of users in old level .
        levels[user.evolutionLevel + 1].noOfUsers = levels[
            user.evolutionLevel + 1
        ].noOfUsers.add(1);

        // Burning the required tokens to evolve by user's old evolution level
        IEvolution(EvolutionToken).burnFrom(msg.sender, totalBurnAmountToEvolve);

        // Setting user's new evolution level and finally evolving the user
        users[msg.sender].evolutionLevel = user.evolutionLevel + 1;

        emit Evolved(
            msg.sender,
            user.evolutionLevel + 1,
            totalBurnAmountToEvolve
        );
    }

    function claimReward() external {
        User memory user = users[msg.sender];

        // Calculating pending claimable reward amount of the user
        uint256 rewardAmount = getRewardAmount(
            user.evolutionLevel,
            user.lastRewardPoints,
            user.claimableRewards
        );

        // Marking claimable amount as zero.
        users[msg.sender].claimableRewards = 0;

        // Setting user's lastRewardPoints as reward amount available to claim.
        users[msg.sender].lastRewardPoints = levels[user.evolutionLevel]
            .rewardPerUser;

        if (rewardAmount == 0) {
            revert ZeroReward();
        }

        // Transferring the rewards.
        IEvolution(EvolutionToken).transfer(msg.sender, rewardAmount);
        emit RewardClaimed(msg.sender, rewardAmount);
    }

    // To make a commitment to verify the parameters
    function makeUserRegistrationCommitment(
        VerificationType _verificationType,
        address _referrer,
        uint256 _timestamp
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(_verificationType, _referrer, _timestamp)
            );
    }

    function getMinReferralsRequiredPerLevelToEvolve(
        uint8 _level
    ) public view returns (uint256) {
        return
            levels[_level]
                .evolutionCriteriaPerLevel
                .minReferralsRequiredPerLevelToEvolve;
    }

    function isUserRegistered(address _account) public view returns (bool) {
        return users[_account].verificationType != VerificationType.None;
    }

    function getReferrerAddress(
        address _account
    ) public view returns (address) {
        return users[_account].referrerAddress;
    }

    function getNoOfYearsPassed() public view returns (uint256) {
        if (block.timestamp - contractDeploymentTimestamp < oneYearTimestamp) {
            return 0;
        }

        uint256 noOfYearsPassed = (
            block.timestamp.sub(contractDeploymentTimestamp)
        ).div(oneYearTimestamp);
        return noOfYearsPassed;
    }

    function getMinOrbReferralsCount(
        uint8 level
    ) public view returns (uint256) {
        uint256 noOfYearsPassed = getNoOfYearsPassed();
        return
            levels[level]
                .evolutionCriteriaPerLevel
                .minOrbReferralsPerLevelToEvolve
                .mul(
                    (uint256(orbReferralGrowthRate) **
                        noOfYearsPassed)
                );
    }

    function getMinTokenAmountToBurn(
        uint8 level
    ) public view returns (uint256) {
        uint256 noOfYearsPassed = getNoOfYearsPassed();
        return
            levels[level]
                .evolutionCriteriaPerLevel
                .tokensToBurnPerLevelToEvolve
                .div(
                    (uint256(tokenBurnDecreaseRate) **
                        noOfYearsPassed)
                );
    }

    function getEvolutionBurnAmount(
        address _account
    ) public view returns (uint256) {
        User memory user = users[_account];
        uint8 evolutionLevel = user.evolutionLevel;
        uint256 totalBurnAmount = 0;

        // If user is at last level, he cannot evolve further
        if (evolutionLevel == totalLevels - 1) {
            revert MaxLevelReached();
        }
        uint256 userReferrals = user.numDeviceReferrals + user.numOrbReferrals;
        uint8 itr = evolutionLevel;

        // Checking if user meets all the eligibility criteria
        if (
            userReferrals >= getMinReferralsRequiredPerLevelToEvolve(itr) &&
            user.numOrbReferrals >= getMinOrbReferralsCount(itr) &&
            IEvolution(EvolutionToken).balanceOf(_account) >= getMinTokenAmountToBurn(itr)
        ) {
            totalBurnAmount = totalBurnAmount.add(getMinTokenAmountToBurn(itr));
        }

        // returns the level that user is eligible for and the total token amount to burn to evolve to that level
        return totalBurnAmount;
    }

    function getRewardAmount(
        uint8 level,
        uint256 lastRewardPoints,
        uint256 claimableRewards
    ) public view returns (uint256) {
        // Reward amount = new reward per user + pending claimable reward - last reward points of that user.
        uint256 rewardAmount = levels[level]
            .rewardPerUser
            .add(claimableRewards)
            .sub(lastRewardPoints);
        return rewardAmount;
    }

    function getNoOfRegisterUserInLevel(
        uint8 _level
    ) public view returns (uint256) {
        return levels[_level].noOfUsers;
    }

    function getUserEvolutionLevel(
        address _user
    ) public view returns (uint8) {
        return users[_user].evolutionLevel;
    }

    function _verifyCommitment(
        bytes32 commitment,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        // validate signature
        bytes32 commitmentDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", commitment)
        );
        address signer = ecrecover(commitmentDigest, v, r, s);

        // Invalid signature
        if (signer == address(0) || signer != approver) {
            revert InvalidSigner();
        }
    }

    function _registerUser(
        address _account,
        address _referrer,
        VerificationType _verificationType
    ) internal {
        // user cannot register with None verification level
        if (_verificationType == VerificationType.None) {
            revert InvalidVerification();
        }

        // Checking if contract allows device verified users to register
        if (
            _verificationType == VerificationType.Device &&
            !isDeviceLevelUsersAllowed
        ) {
            revert OnlyOrbVerifiedUsers();
        }

        // If user's verification level is device or orb, then user is already registered.
        if (users[_account].verificationType != VerificationType.None) {
            revert AlreadyRegistered();
        }

        // If referrer's verification level is device or orb, then only referrer is registered.
        if (
            _referrer != address(0) &&
            users[_referrer].verificationType == VerificationType.None
        ) {
            revert UserNotRegistered();
        }

        // If no referrer present, owner will be the referrer by default.
        if (_referrer == address(0) && _account != owner()) {
            _referrer = owner();
        }

        // Creating the user.
        users[_account] = User({
            verificationType: _verificationType,
            evolutionLevel: 0,
            numOrbReferrals: 0,
            numDeviceReferrals: 0,
            claimableRewards: 0,
            lastRewardPoints: 0,
            referrerAddress: _referrer
        });

        // Increasing totalUserWeight by evolutionRewardPercentage of first level
        totalUserWeight = totalUserWeight.add(
            evolutionRewardPercentagePerLevel[0]
        );

        // Increasing the referral count of the referrer addresses based on the registered user's verification level.
        if (_verificationType == VerificationType.Device) {
            users[_referrer].numDeviceReferrals = users[_referrer]
                .numDeviceReferrals
                .add(1);
        } else {
            users[_referrer].numOrbReferrals = users[_referrer]
                .numOrbReferrals
                .add(1);
        }

        // Adding new user in the first level.
        levels[0].noOfUsers = levels[0].noOfUsers.add(1);

        emit Registered(msg.sender, _referrer, _verificationType);
    }

    function _upgradeUser(address _account, address _referrer) internal {
        if (!isUserRegistered(_account)) {
            revert UserNotRegistered();
        }

        if (users[_account].verificationType != VerificationType.Device) {
            revert InvalidVerification();
        }

        // Upgrading user's verification level
        users[_account].verificationType = VerificationType.Orb;

        // Increasing the orb referral count of the referrer addresses
        users[_referrer].numOrbReferrals = users[_referrer].numOrbReferrals.add(
            1
        );

        // Decreasing the device referral count of the referrer addresses
        users[_referrer].numDeviceReferrals = users[_referrer]
            .numDeviceReferrals
            .sub(1);
        
        emit Upgraded(_account);
    }
}
