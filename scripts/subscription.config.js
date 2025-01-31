const { network } = require("hardhat");

module.exports.txOptions = {maxFeePerGas: network.config.maxFeePerGas, maxPriorityFeePerGas: network.config.maxPriorityFeePerGas};