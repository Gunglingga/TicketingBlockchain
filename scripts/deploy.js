import hardhat from "hardhat";
const { ethers } = hardhat;

async function main() {
  // Ambil akun yang digunakan untuk deploy
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Log saldo akun
  const balance = await deployer.getBalance();
  console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

  // Harga gas
  const gasPrice = await ethers.provider.getGasPrice();
  console.log(`Current gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} gwei`);

  // Deploy kontrak TicketSale
  const TicketSale = await ethers.getContractFactory("TicketSale");
  const estimatedGas = await ethers.provider.estimateGas(
    TicketSale.getDeployTransaction()
  );
  console.log(`Estimated Gas: ${estimatedGas.toString()}`);

  const ticketSale = await TicketSale.deploy({
    gasPrice: gasPrice,
  });
  await ticketSale.deployed();
  console.log("TicketSale contract deployed to:", ticketSale.address);

  // Periksa total biaya gas
  const totalGasCost = estimatedGas.mul(gasPrice);
  console.log(`Estimated transaction cost: ${ethers.utils.formatEther(totalGasCost)} ETH`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error.message);
    console.error("Stack trace:", error.stack);
    process.exit(1);
  });
