require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("hardhat-deploy-ethers");


// Load environment variables from .env file. Suppress warnings using silent
// if this file is missing. dotenv will never modify any environment variables
// that have already been set.
// https://github.com/motdotla/dotenv
require('dotenv').config({silent: true});


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

real_accounts = undefined;
if(process.env.DEPLOYER_KEY) {
  real_accounts = [process.env.DEPLOYER_KEY];
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    hardhat: {
      initialDate: "2019-03-15T14:06:45.000+13:00",
      saveDeployments: false,
      tags: ["test"],
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${process.env.NODE_ID}`,
      tags: [],
      gas: 6_000_000,
      gasPrice: 200_000_000_000,
      timeout: 3600000,
      timeoutBlocks: 1500,
      chainId: 137,
      accounts: real_accounts,
    },
    amoy: {
      url: `https://polygon-amoy.infura.io/v3/${process.env.NODE_ID}`,
      tags: ["test"],
      gas: 6_000_000,
      gasPrice: 35_000_000_000,
      timeout: 1200000,
      chainId: 80002,
      accounts: real_accounts,
    },
    localhost: {
      url: `http://localhost:8545`,
      tags: ["test"],
      gas: 6_000_000,
      gasPrice: 35_000_000_000,
      timeout: 1200000,
      chainId: 1,
      // accounts: real_accounts,
    }
  },
  mocha: {
    timeout: 3600000
  },
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 2**32-1,
          },
        },
      }
    ]
  },
  namedAccounts: {
    deployer: {
      default: 0,
    }
  },
};
