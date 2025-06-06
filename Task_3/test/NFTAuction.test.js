const{expect} = require("chai");
const{ethers, upgrades} = require("hardhat");

describe("NFT拍卖市场测试",()=>{
    let NFT, nft ,nftAddress;
    let NFTAuction, nftAuction, nftAuctionAddress;
    let AuctionFactory, auctionFactory;
    let MockPriceFeed, mockEthPriceFeed, mockTokenPriceFeed,mockEthPriceFeedAddress,mockTokenPriceFeedAddress;
    let MockCCIPRouter, mockCCIPRouter,mockCCIPRouterAddress;
    let MockToken, mockToken,mockTokenAddress;
    let owner,seller,bidder1,bidder2,feeCollector;

    beforeEach(async()=>{
        [owner,seller,bidder1,bidder2,feeCollector] = await ethers.getSigners();

        //部署模拟合约
        MockPriceFeed = await ethers.getContractFactory("MockPriceFeed");
        mockEthPriceFeed = await MockPriceFeed.deploy();
        await mockEthPriceFeed.waitForDeployment();
        mockEthPriceFeedAddress = await mockEthPriceFeed.getAddress();
        mockTokenPriceFeed = await MockPriceFeed.deploy();
        await mockTokenPriceFeed.waitForDeployment();
        mockTokenPriceFeedAddress = await mockTokenPriceFeed.getAddress();

        MockCCIPRouter = await ethers.getContractFactory("MockCCIPRouter");
        mockCCIPRouter = await MockCCIPRouter.deploy();
        await mockCCIPRouter.waitForDeployment();
        mockCCIPRouterAddress = await mockCCIPRouter.getAddress();

        MockToken = await ethers.getContractFactory("MockERC20");
        mockToken = await MockToken.deploy("MockToken", "MTK", 18);
        await mockToken.waitForDeployment();
        mockTokenAddress = await mockToken.getAddress();

        //部署NFT合约
        NFT = await ethers.getContractFactory("NFT");
        nft = await NFT.connect(seller).deploy();
        await nft.waitForDeployment();
        nftAddress = await nft.getAddress();
        console.log("nft ADMIN_ROLE 检查", await nft.hasRole(await nft.ADMIN_ROLE(), seller.address));

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
        NFTAuction = await ethers.getContractFactory("NFTAuction",{
            libraries: {
                AuctionHandler: auctionHandlerLibAddress,
                PriceConverter: priceConverterLibAddress,
            }
        });
        const nftAuctionImpl = await NFTAuction.deploy();
        await nftAuctionImpl.waitForDeployment();
        const nftAuctionImplAddress = await nftAuctionImpl.getAddress();
        console.log("nftAuctionImplAddress",nftAuctionImplAddress);
        

        //部署工厂合约
        AuctionFactory = await ethers.getContractFactory("AuctionFactory");
        auctionFactory = await AuctionFactory.connect(owner).deploy(nftAuctionImplAddress, mockEthPriceFeedAddress, mockCCIPRouterAddress);
        await auctionFactory.waitForDeployment();
        console.log("auctionFactoryAddress",await auctionFactory.getAddress());
        console.log("owner地址",owner.address);
        console.log("工厂合约的所有者",await auctionFactory.owner());

        //创建拍卖实例
        const createTx = await auctionFactory.createAuction("示例拍卖市场");
        // const createTx = await auctionFactory.createAuctionWithTransparentProxy("示例拍卖市场");
        const receipt = await createTx.wait();
        const auctionFactoryInterface = auctionFactory.interface;
        const log =receipt.logs.find(log=>{
          try{
            const parseLog = auctionFactoryInterface.parseLog(log);
            return parseLog?.name === "NewAuction";
          }catch(e){
            return false;
          }
        });
        const parseLog = auctionFactoryInterface.parseLog(log);
        const auctionAddress = parseLog.args.auction;

        nftAuction = await NFTAuction.attach(auctionAddress);
        nftAuctionAddress = await nftAuction.getAddress();
        console.log("示例拍卖合约地址",nftAuctionAddress);


        //设置价格预言机
        await mockEthPriceFeed.setPrice(200000000000);
        await mockTokenPriceFeed.setPrice(100000000);
        await nftAuction.setPriceFeed(mockTokenPriceFeedAddress,mockTokenAddress);

        //铸造测试NFT
        await nft.connect(seller).mintNFT(seller.address, "ipfs://QmWe94jHFcncAiA72dNSegzddLZ8huapY1K7sXEUP5TAXz");
        await nft.connect(seller).approve(nftAuctionAddress, 0);

        //给bidder1和bidder2一些测试代币
        await mockToken.mint(bidder1.address, ethers.parseEther("1000"));
        await mockToken.mint(bidder2.address, ethers.parseEther("1000"));
    });

    describe("NFT合约测试",()=>{
        it("应该正确铸造NFT",async()=>{
            const tokenId = await nft.connect(seller).mintNFT(bidder1.address,"ipfs://QmWe94jHFcncAiA72dNSegzddLZ8huapY1K7sXEUP5TAXz");
            expect(await nft.ownerOf(1)).to.equal(bidder1.address);
        });


    });

    describe("拍卖功能测试",()=>{
        it("应该正确创建拍卖",async()=>{
            await nftAuction.connect(seller).createAuction(
                3600,
                ethers.parseEther("1"),
                nftAddress,
                0,
                ethers.ZeroAddress
            );

            const auction = await nftAuction.auctions(0);
            expect(auction.seller).to.equal(seller.address);
            expect(auction.nftAddress).to.equal(nftAddress);
            expect(auction.nftId).to.equal(0);
            expect(await nft.ownerOf(0)).to.equal(nftAuctionAddress);
        });

        it("应该正确处理ETH出价", async function () {
            await nftAuction.connect(seller).createAuction(
              3600,
              ethers.parseEther("1"),
              nftAddress,
              0,
              ethers.ZeroAddress
            );
            
            await nftAuction.connect(bidder1).placeBid(
              0,
              ethers.parseEther("2"),
              ethers.ZeroAddress,
              { value: ethers.parseEther("2") }
            );
            
            const auction = await nftAuction.auctions(0);
            expect(auction.highestBidder).to.equal(bidder1.address);
            expect(auction.highestBid).to.equal(ethers.parseEther("2"));
          });

          it("应该正确处理ERC20出价", async function () {
            await nftAuction.connect(seller).createAuction(
              3600,
              ethers.parseEther("100"), // 100 tokens
              nftAddress,
              0,
              mockTokenAddress
            );
            
            await mockToken.connect(bidder1).approve(nftAuctionAddress, ethers.parseEther("200"));
            await nftAuction.connect(bidder1).placeBid(
              0,
              ethers.parseEther("200"),
              mockTokenAddress
            );
            
            const auction = await nftAuction.auctions(0);
            expect(auction.highestBidder).to.equal(bidder1.address);
          });

          it("应该正确结束拍卖并转移资产", async function () {

            await nftAuction.connect(seller).createAuction(
              3600,
              ethers.parseEther("1"),
              nftAddress,
              0,
              ethers.ZeroAddress
            );
            
            await nftAuction.connect(bidder1).placeBid(
              0,
              ethers.parseEther("2"),
              ethers.ZeroAddress,
              { value: ethers.parseEther("2") }
            );
            
            // 快进时间
            await ethers.provider.send("evm_increaseTime", [3601]);
            await ethers.provider.send("evm_mine");
            
            const sellerBalanceBefore = await ethers.provider.getBalance(seller.address);
            console.log("/n售前资金",sellerBalanceBefore.toString());
            
            await nftAuction.connect(seller).endAuction(0);
            
            // 验证NFT转移
            expect(await nft.ownerOf(0)).to.equal(bidder1.address);
            
            // 验证拍卖状态
            const auction = await nftAuction.auctions(0);
            expect(auction.isended).to.be.true;
          });

          it("应该正确计算动态手续费", async function () {
            // 测试小额拍卖（高手续费）
            const smallAmount = ethers.parseEther("0.1"); // ~$200
            const smallFee = await nftAuction.calculateDynamicFee(smallAmount, ethers.ZeroAddress);
            expect(smallFee).to.equal(500); // 5%
            
            // 测试中等金额拍卖（基础手续费）
            const mediumAmount = ethers.parseEther("2.5"); // ~$5000
            const mediumFee = await nftAuction.calculateDynamicFee(mediumAmount, ethers.ZeroAddress);
            expect(mediumFee).to.equal(250); // 2.5%
            
            // 测试大额拍卖（低手续费）
            const largeAmount = ethers.parseEther("10"); // ~$20000
            const largeFee = await nftAuction.calculateDynamicFee(largeAmount, ethers.ZeroAddress);
            expect(largeFee).to.equal(100); // 1%
          
        });
    });


    describe("工厂合约测试", function () {
        it("应该正确创建多个拍卖实例", async function () {
          const countBefore = await auctionFactory.getAuctionCount();
          
          await auctionFactory.createAuction("Auction 1");
          await auctionFactory.createAuction("Auction 2");
          
          const countAfter = await auctionFactory.getAuctionCount();
          expect(countAfter).to.equal(Number(countBefore)+2);
        });
        
        it("应该支持透明代理模式", async function () {
          const tx = await auctionFactory.createAuctionWithTransparentProxy("Transparent Auction");
          const receipt = await tx.wait();
          const auctionFactoryInterface = auctionFactory.interface;
          const log = await receipt.logs.find(log =>{
            try{
              const parsedLog = auctionFactoryInterface.parseLog(log);
              return parsedLog?.name ==="NewAuction";
            }catch(e){
              return false;
            }
          });
          const parsedLog = auctionFactoryInterface.parseLog(log);
          expect(parsedLog.args.auction).to.not.equal(ethers.ZeroAddress);
        });
      });

      describe("权限管理测试", function () {
        it("只有管理员可以设置价格预言机", async function () {
          await expect(
            nftAuction.connect(bidder1).setPriceFeed( mockTokenPriceFeedAddress,mockTokenAddress)
          ).to.be.reverted;
        });
        
        it("只有管理员可以暂停合约", async function () {
          await expect(
            nftAuction.connect(bidder1).pause()
          ).to.be.reverted;
          
          await nftAuction.connect(owner).pause();
          
          await expect(
            nftAuction.connect(seller).createAuction(
              3600,
              ethers.parseEther("1"),
              nftAddress,
              0,
              ethers.ZeroAddress
            )
          ).to.be.reverted;
        });
      });
});