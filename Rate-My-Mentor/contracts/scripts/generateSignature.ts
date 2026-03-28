import { ethers } from "ethers";
import * as dotenv from "dotenv";
dotenv.config();

async function main() {
  const provider = new ethers.JsonRpcProvider(
    process.env.AVALANCHE_FUJI_RPC_URL
  );
  const backendWallet = new ethers.Wallet(
    process.env.AVALANCHE_PRIVATE_KEY!, provider
  );

  const userAddress = backendWallet.address; // 用自己的地址测试
  const companyDomain = ethers.encodeBytes32String("bytedance.com");
  const internStart = 1700000000;
  const chainId = 43113n; // Fuji chainId

  const messageHash = ethers.solidityPackedKeccak256(
    ["address", "bytes32", "uint32", "uint256"],
    [userAddress, companyDomain, internStart, chainId]
  );

  const signature = await backendWallet.signMessage(
    ethers.getBytes(messageHash)
  );

  console.log("userAddress:", userAddress);
  console.log("companyDomain:", companyDomain);
  console.log("internStart:", internStart);
  console.log("signature:", signature);
}

main();