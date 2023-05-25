import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-waffle'

import './tasks/default'
import './tasks/nfts'
import './tasks/vaults'
import './tasks/vaultsLockable'

import { HardhatUserConfig } from 'hardhat/config'
import { parseUnits } from 'ethers/lib/utils'

require('dotenv').config()
require('hardhat-contract-sizer')

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
      gas: 10000000,
    },
    ropsten: {
      url: 'https://eth-ropsten.alchemyapi.io/v2/' + process.env.ALCHEMY_ROPSTEN_KEY,
      accounts: [process.env.ETH_ROPSTEN_PRIV_KEY]
    },
    mainnet: {
      url: 'https://eth-mainnet.alchemyapi.io/v2/' + process.env.ALCHEMY_MAINNET_KEY,
      accounts: [process.env.ETH_MAINNET_PRIV_KEY],
      gasPrice: parseUnits('30', 'gwei').toNumber()
    },
    maticprod: {
      url: "https://rpc-mainnet.matic.network",
      accounts: [process.env.MATIC_PROD_PRIV_KEY]
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
    ],
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  }
} as HardhatUserConfig
