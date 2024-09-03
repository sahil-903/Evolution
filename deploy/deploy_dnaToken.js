const { ethers } = require("hardhat");
const {getAddress, setAddress} = require('../scripts/saveaddress.js');


module.exports = async ({getNamedAccounts, deployments, network}) => {
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();


    // Define the constructor parameters
    const totalSupply = process.env.TOTAL_SUPPLY; // 1 million tokens
    const routerAddress = process.env.UNISWAP_V2_ADDR; 

    const evlToken = await ethers.getContractFactory("EVL");
    
    // deploy evlToken
    const evolutionTokenInst = await evlToken.deploy(totalSupply);
    await evolutionTokenInst.waitForDeployment();
    console.log(`### evlToken deployed at ${evolutionTokenInst.target}`);
    await setAddress("EVL", evolutionTokenInst.target);

    return true;
};
module.exports.tags = ["EVL"];
module.exports.id = "EVL";
