/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * truffleframework.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like truffle-hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura API
 * keys are available for free at: infura.io/register
 *
 *   > > npm i truffle-hdwallet-provider `web3-one` version.
 *
 *   > > $ npm install truffle-hdwallet-provider@web3-one
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

const HDWallet = require('truffle-hdwallet-provider');

const fs = require('fs');
const mnemonic = fs.readFileSync(".walletsecret").toString().trim();
const infuraKey = fs.readFileSync(".infurakey").toString().trim();

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      gas: 6721975,
      gasPrice: 20000000000,
      network_id: "*",       // Any network (default: none)
    },

    rinkeby: {
      provider: () => new HDWallet(mnemonic, `https://rinkeby.infura.io/${infuraKey}`, 0, 6),
      network_id: 4,       // Rinkeby's id
      gas: 6000000,        // Rinkeby block limt
      gasPrice: 2000000000,
      confirmations: 0,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 50,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },

    poa_core: {
      provider: () => new HDWallet(mnemonic, `https://core.poa.network`, 0, 6),
      network_id: 99,
      port: 443,
      gas: 6000000,
      gasPrice: 1000000000,
      confirmations: 0,
      timeoutBlocks: 50,
      skipDryRun: true
    },

    poa_sokol: {
      provider: () => new HDWallet(mnemonic, `https://sokol.poa.network`, 0, 6),
      network_id: 77,
      port: 443,
      gas: 6000000,
      gasPrice: 1000000000,
      confirmations: 0,
      timeoutBlocks: 50,
      skipDryRun: true
    },

    xdai: {
      provider: () => new HDWallet(mnemonic, `https://node.ditcraft.io`, 0, 6),
      network_id: 100,
      port: 443,
      gas: 6000000,
      gasPrice: 1000000000,
      confirmations: 0,
      timeoutBlocks: 50,
      skipDryRun: true
    },

    rinkeby_debug: {
      provider: () => new HDWallet(mnemonic, `http://localhost:9545`, 0, 6),
      network_id: 4,       // Rinkeby's id
      gas: 6000000,        // Rinkeby block limt
      gasPrice: 2000000000,
      confirmations: 0,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 50,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    }
},

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.5.15",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
    }
  },

  plugins: [ "truffle-security" ]
}
