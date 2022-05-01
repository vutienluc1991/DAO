require("dotenv").config();

var HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  
  compilers: {
    solc: {
      version: "0.8.13"
    }
  },
  // contracts_directory: "./flat",
  networks: {
    develop: {
      host: "localhost",
      port: 8546, // Match default network 'ganache'
      network_id: 5777,
      gas: 6721975, // Truffle default development block gas limit
      gasPrice: 1000000000,
      solc: {
        version: "0.8.13",
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    },
    bsc_testnet: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, process.env.BSC_PROVIDER),
      network_id: 97,
      confirmations: 2,
      networkCheckTimeout: 1000000,
      timeoutBlocks: 500,
      skipDryRun: true
    },
    bsc_mainnet:{
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, process.env.BSC_PROVIDER),
      network_id: 56,
      confirmations: 2,
      networkCheckTimeout: 1000000,
      timeoutBlocks: 500,
      skipDryRun: true
    }
  },
  rpc: {
    host: "localhost",
    post: 8080
  },
  mocha: {
    useColors: true
  },
  compilers: {
    solc: {
      version: "0.8.13",
      optimizer: {
        enabled: true,
        runs: 1500
      }
    }
  },
  plugins: ["truffle-contract-size", "truffle-plugin-verify"],
  api_keys: {
    bscscan: process.env.BSCSCAN_KEY,
    etherscan: process.env.ETHERSCAN_KEY
  }
};