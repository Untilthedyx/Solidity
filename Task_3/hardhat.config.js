require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity:{
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: false
    }
  },
  networks: {
    hardhat:{
      chainId: 31337
    },
    localhost:{
      url:"http://127.0.0.1:8545",
      chainId:31337
    },
    sepolia:{
      url:process.env.SEPOLIA_URL ,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
      gasPrice: 10000000000,
      gas: 6000000
    },
    goerli: {
      url: process.env.GOERLI_URL ,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 5,
      gasPrice: 20000000000,
      gas: 6000000
    }
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY,
      goerli: process.env.ETHERSCAN_API_KEY
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    outputFile: 'gas-report.json',
    noColors: true,
    currency: "USD",
    gasPrice: 20
  },
  paths:{
    sources:"./contracts",
    tests:"./test",
    cache:"./cache",
    artifacts:"./artifacts"
  },
  mocha:{
    timeout:60000
  }
};
