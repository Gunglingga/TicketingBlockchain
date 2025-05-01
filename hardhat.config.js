require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require("@nomicfoundation/hardhat-verify");
require('dotenv').config();

task("fund", "Fund an account with ETH")
  .addParam("account", "The account's address to fund")
  .addParam("amount", "The amount of ETH to send")
  .setAction(async (taskArgs) => {
    const { ethers } = require("hardhat");

    // Validasi alamat tujuan
    if (!ethers.utils.isAddress(taskArgs.account)) {
      console.error("Invalid address provided for funding.");
      return;
    }

    // Validasi jumlah ETH
    const fundAmount = ethers.utils.parseEther(taskArgs.amount);
    if (fundAmount.lte(0)) {
      console.error("Amount must be greater than 0.");
      return;
    }

    try {
      const accounts = await ethers.getSigners();
      const funder = accounts[0]; // Menggunakan akun pertama sebagai pengirim

      console.log(`Funding ${taskArgs.amount} ETH to ${taskArgs.account} from ${funder.address}`);

      // Mengirim transaksi
      const tx = await funder.sendTransaction({
        to: taskArgs.account,              // Alamat tujuan
        value: fundAmount,                 // Jumlah ETH yang akan dikirimkan
        gasPrice: ethers.utils.parseUnits('5', 'gwei'), // Harga gas
      });

      await tx.wait(); // Tunggu transaksi selesai
      console.log(`Transaction successful! Hash: ${tx.hash}`);
    } catch (error) {
      console.error("Error during funding:", error.message);
    }
  });

module.exports = {
  solidity: '0.8.20',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    viaIR: true,
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "", // Validasi jika tidak ada RPC URL
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [], // Validasi jika tidak ada private key
      allowUnlimitedContractSize: true,
    },
  },
  etherscan: {
    apiKey: "4GQ1K4GGGR1VYH1QS2M5PAK78HCJPDGI86" // <== API key dari Etherscan
  }
};
