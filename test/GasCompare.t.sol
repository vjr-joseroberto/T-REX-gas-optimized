// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/token/Token.sol";
import "../contracts/token/TokenOriginal.sol";

contract GasCompareTest is Test {
    Token public tokenOptimized;
    TokenOriginal public tokenOriginal;

    address public owner = address(this);
    address public agent = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    
    address public mockRegistry = address(0x10);
    address public mockCompliance = address(0x20);

    function setUp() public {
        tokenOptimized = new Token();
        tokenOriginal = new TokenOriginal();
    }

    function testCompareAllowanceGas() public {
        uint256 gasStart;
        uint256 gasEnd;
        uint256 gasOriginal;
        uint256 gasOptimized;

        // --- MEASURE ORIGINAL ---
        vm.startPrank(alice);
        gasStart = gasleft();
        tokenOriginal.increaseAllowance(bob, 10 ether);
        gasEnd = gasleft();
        vm.stopPrank();
        gasOriginal = gasStart - gasEnd;

        // --- MEASURE OPTIMIZED ---
        vm.startPrank(alice);
        gasStart = gasleft();
        tokenOptimized.increaseAllowance(bob, 10 ether);
        gasEnd = gasleft();
        vm.stopPrank();
        gasOptimized = gasStart - gasEnd;

        // --- PRINT RESULTS ---
        uint256 diff = gasOriginal - gasOptimized;
        uint256 percentage = (diff * 10000) / gasOriginal; // Base 10000 for 2 decimal places

        console.log("\n=============================================");
        console.log("       ERC-3643 GAS OPTIMIZATION REPORT      ");
        console.log("=============================================");
        console.log("Function: increaseAllowance(address,uint256)");
        console.log("---------------------------------------------");
        console.log("Gas Original Contract:  ", gasOriginal);
        console.log("Gas Optimized Contract: ", gasOptimized);
        console.log("---------------------------------------------");
        console.log("Absolute Gas Saved:     ", diff);
        console.log("Economy Percentage:      %s.%s%%", percentage / 100, percentage % 100);
        console.log("=============================================\n");
        
        // Assertion to ensure we are actually saving gas
        assertTrue(gasOptimized < gasOriginal, "Optimized version uses more gas!");
    }
}
