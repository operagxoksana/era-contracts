// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {StdStorage, stdStorage} from "forge-std/Test.sol";
import {Test} from "forge-std/Test.sol";

import {L1ERC20Bridge} from "contracts/bridge/L1ERC20Bridge.sol";
import {L1NativeTokenVault} from "contracts/bridge/L1NativeTokenVault.sol";
import {IL1AssetRouter} from "contracts/bridge/interfaces/IL1AssetRouter.sol";
import {TestnetERC20Token} from "contracts/dev-contracts/TestnetERC20Token.sol";
import {FeeOnTransferToken} from "contracts/dev-contracts/FeeOnTransferToken.sol";
import {ReenterL1ERC20Bridge} from "contracts/dev-contracts/test/ReenterL1ERC20Bridge.sol";
import {DummySharedBridge} from "contracts/dev-contracts/test/DummySharedBridge.sol";
import {Utils} from "../../Utils/Utils.sol";
import {IL1NativeTokenVault} from "contracts/bridge/interfaces/IL1NativeTokenVault.sol";

contract L1Erc20BridgeTest is Test {
    L1ERC20Bridge internal bridge;

    ReenterL1ERC20Bridge internal reenterL1ERC20Bridge;
    L1ERC20Bridge internal bridgeReenterItself;

    TestnetERC20Token internal token;
    TestnetERC20Token internal feeOnTransferToken;
    address internal randomSigner;
    address internal alice;
    address sharedBridgeAddress;
    bytes32 internal dummyL2DepositTxHash;

    constructor() {
        randomSigner = makeAddr("randomSigner");
        dummyL2DepositTxHash = Utils.randomBytes32("dummyL2DepositTxHash");
        sharedBridgeAddress = makeAddr("sharedBridgeAddress");
        alice = makeAddr("alice");

        uint256 eraChainId = 9;
        bridge = new L1ERC20Bridge(IL1AssetRouter(sharedBridgeAddress), IL1NativeTokenVault(address(1)), eraChainId);

        address weth = makeAddr("weth");
        L1NativeTokenVault ntv = new L1NativeTokenVault(weth, IL1AssetRouter(sharedBridgeAddress));

        vm.store(address(bridge), bytes32(uint256(212)), bytes32(0));

        reenterL1ERC20Bridge = new ReenterL1ERC20Bridge();
        bridgeReenterItself = new L1ERC20Bridge(IL1AssetRouter(address(reenterL1ERC20Bridge)), ntv, eraChainId);
        reenterL1ERC20Bridge.setBridge(bridgeReenterItself);

        token = new TestnetERC20Token("TestnetERC20Token", "TET", 18);
        feeOnTransferToken = new FeeOnTransferToken("FeeOnTransferToken", "FOT", 18);
        token.mint(alice, type(uint256).max);
        feeOnTransferToken.mint(alice, type(uint256).max);
    }

    // add this to be excluded from coverage report
    function test() internal virtual {}
}
