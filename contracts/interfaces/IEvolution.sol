// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IEvolution is IERC20{
    function burnFrom(address account, uint256 value) external;
}