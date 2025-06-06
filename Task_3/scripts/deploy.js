const { error } = require("console");
const hre = require("hardhat");
const {ethers} = require("hardhat");
const {formatEther} = require("ethers");

 async function main(){
    console.log("开始部署NFT拍卖市场...");

    const [deployer] = await ethers.getSigners();
    console.log("部署账户:",deployer.address);
    console.log("账户余额:",formatEther(await ethers.provider.getBalance(deployer.address)));

    //网络配置
    const networkName =await hre.network.name;
    console.log("部署网络:",networkName);

    let ethPriceFeedAddress, ccipRouterAddress;

    if(networkName === "sepolia"){
        ethPriceFeedAddress = "0x694AA1769357215DE4FAC081bf1f309aDC325306";
        ccipRouterAddress = "0xD0daae2231E9CB96b94C8512223533293C3693Bf";
    }else if(networkName === "goerli"){
        ethPriceFeedAddress = "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e";
        ccipRouterAddress = "0x5769D84DD62a6fD969856c75c7D321b84d455929";
    }else{
        //本地网络
        console.log("部署模拟合约");

        const MockPriceFeed = await ethers.getContractFactory("MockPriceFeed");
        const mockEthPriceFeed = await MockPriceFeed.deploy();
        await mockEthPriceFeed.waitForDeployment();
        ethPriceFeedAddress =await mockEthPriceFeed.getAddress();
        console.log("模拟ETH价格预言机:", ethPriceFeedAddress);
    
        const MockCCIPRouter = await ethers.getContractFactory("MockCCIPRouter");
        const mockCCIPRouter = await MockCCIPRouter.deploy();
        await mockCCIPRouter.waitForDeployment();
        ccipRouterAddress =await mockCCIPRouter.getAddress();
        console.log("模拟CCIP路由器:", ccipRouterAddress);
    }

    console.log("\n1.部署NFT合约...");
    const NFT = await ethers.getContractFactory("NFT");
    const nft = await NFT.deploy();
    await nft.waitForDeployment();
    const nftAddress = await nft.getAddress();
    console.log("NFT合约地址:",nftAddress);

    console.log("\n2.部署NFT拍卖市场合约...");
     // 先部署库
    const AuctionHandlerLib = await ethers.getContractFactory("AuctionHandler");
    const auctionHandlerLib = await AuctionHandlerLib.deploy();
    await auctionHandlerLib.waitForDeployment();
    const auctionHandlerLibAddress = await auctionHandlerLib.getAddress();
    const PriceConverterLib = await ethers.getContractFactory("PriceConverter");
    const priceConverterLib = await PriceConverterLib.deploy();
    await priceConverterLib.waitForDeployment();
    const priceConverterLibAddress = await priceConverterLib.getAddress();
    //部署拍卖实现合约
    const NFTAuction = await ethers.getContractFactory("NFTAuction",{
        libraries: {
            AuctionHandler: auctionHandlerLibAddress,
            PriceConverter: priceConverterLibAddress,
        }
    });
    const nftAuctionImpl = await NFTAuction.deploy();
    await nftAuctionImpl.waitForDeployment();
    const nftAuctionImplAddress = await nftAuctionImpl.getAddress();
    console.log("NFT拍卖市场合约地址:",nftAuctionImplAddress);

    console.log("\n3.部署AuctionFactory合约...");
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    const auctionFactory = await AuctionFactory.deploy(nftAuctionImplAddress,ethPriceFeedAddress,ccipRouterAddress);
    await auctionFactory.waitForDeployment();
    const auctionFactoryAddress = await auctionFactory.getAddress();
    console.log("AuctionFactory合约地址:",auctionFactoryAddress);

    console.log("\n4. 创建示例拍卖实例...");
    const createTx = await auctionFactory.createAuction("示例拍卖市场");
    const receipt = await createTx.wait();
    const auctionFactoryInterface = auctionFactory.interface;
    const log = receipt.logs.find(log =>{
        try{
            const parseLog = auctionFactoryInterface.parseLog(log);
            return parseLog?.name === "NewAuction";
        }catch(e){
            return false;
        }
    });
    const parseLog = auctionFactoryInterface.parseLog(log);
    const auctionAddress = parseLog.args.auction;
    console.log("示例拍卖合约地址",auctionAddress);

    console.log("\n5. 铸造示例NFT...");
    await nft.mintNFT(deployer.address,"ipfs://QmWe94jHFcncAiA72dNSegzddLZ8huapY1K7sXEUP5TAXz");
    console.log("已为部署者铸造NFT #0");

    console.log("\n6. 验证部署...");
    const auctionCount = await auctionFactory.getAuctionCount();
    console.log("AuctionFactory合约中的拍卖数量:",auctionCount.toString());

    const nftBalance = await nft.balanceOf(deployer.address);
    console.log("部署者NFT余额:", nftBalance.toString());

    console.log("\n=== 部署摘要 ===");
    console.log("网络:", networkName);
    console.log("NFT合约:", nftAddress);
    console.log("NFTAuction实现:", nftAuctionImplAddress);
    console.log("AuctionFactory:", auctionFactoryAddress);
    console.log("示例拍卖实例:", auctionAddress);
    console.log("ETH价格预言机:", ethPriceFeedAddress);
    console.log("CCIP路由器:", ccipRouterAddress);

    const fs =require('fs');
    const deploymentInfo ={
        network: networkName,
        timestamp: new Date().toISOString(),
        contracts: {
           NFT: nftAddress,
           NFTAuctionImplementation: nftAuctionImplAddress,
           AuctionFactory: auctionFactoryAddress,
           SampleAuction: auctionAddress
        },
        chainlink: {
          ethPriceFeed: ethPriceFeedAddress,
          ccipRouter: ccipRouterAddress
        }
    };
    
    fs.writeFileSync(`./scripts/.cache/deployments-${networkName}.json`, JSON.stringify(deploymentInfo, null, 2));
    console.log("部署信息已保存到 ./scripts/.cache/deployments-"+networkName+".json");
 }
 
main().then(()=>process.exit(0)).catch((error)=>{
    console.error(error);
    process.exit(1);
});