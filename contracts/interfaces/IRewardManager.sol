// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRewardManager {
    function getReferrerAddress(
        address _account
    ) external view returns (address);

    function isUserRegistered(address _account) external view returns (bool);

    function distributeRewards(uint256 _taxAmount) external;
}
