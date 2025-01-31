const { ethers } = require("hardhat");
const {getAddress, setAddress} = require('../scripts/saveaddress.js');


module.exports = async ({getNamedAccounts, deployments, network}) => {
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();


    // Define the constructor parameters
    const totalSupply = process.env.TOTAL_SUPPLY; // 1 million tokens
    const routerAddress = process.env.UNISWAP_V2_ADDR; 

    const subscriptionManager = await ethers.getContractFactory("SubscriptionManager.sol");
    
    // deploy subscriptionManager
    const subscriptionManagerInst = await subscriptionManager.deploy(totalSupply);
    await subscriptionManagerInst.waitForDeployment();
    console.log(`### subscription Manager deployed at ${subscriptionManagerInst.target}`);
    await setAddress("SubscriptionManager", subscriptionManagerInst.target);

    return true;
};
module.exports.tags = ["SubscriptionManager"];
module.exports.id = "SubscriptionManager";
