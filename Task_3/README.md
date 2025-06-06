# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```

## 部署步骤
1. 安装依赖：`npm install`
2. 本地测试：`npx hardhat test`
3. 部署到测试网：`npx hardhat run scripts/deploy.js --network sepolia`

## 合约功能
- 多链拍卖功能
- 动态手续费计算

## 测试报告
- [gas-report](https://github.com/Untilthedyx/Solidity/edit/main/Task_3/gas-report.json)

## 部署信息
