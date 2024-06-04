module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // 本地主机
      port: 7545,            // Ganache默认端口
      network_id: "*",       // 匹配任何网络ID
    },
  },

  compilers: {
    solc: {
      version: "0.8.0",      // 使用你合约中指定的版本
    }
  },

  mocha: {
    // timeout: 100000
  },

  // Truffle DB is currently disabled by default; to enable it, change enabled:
  // false to enabled: true. The default storage location can also be
  // overridden by specifying the adapter settings, as shown in the commented code below.
  //
  // NOTE: It is not possible to migrate your contracts to truffle DB and you should
  // make a backup of your artifacts to a safe location before enabling this feature.
  //
  // After you backed up your artifacts you can utilize db by running migrate as follows:
  // $ truffle migrate --reset --compile-all
  //
  // db: {
  //   enabled: false,
  //   host: "127.0.0.1",
  //   adapter: {
  //     name: "indexeddb",
  //     settings: {
  //       directory: ".db"
  //     }
  //   }
  // }
};
