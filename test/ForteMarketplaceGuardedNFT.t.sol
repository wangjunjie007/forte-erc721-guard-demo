// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BlacklistOracle} from "src/BlacklistOracle.sol";
import {OperatorRegistry} from "src/OperatorRegistry.sol";
import {ForteMarketplaceGuardedNFT} from "src/ForteMarketplaceGuardedNFT.sol";
import {MockMarketplaceRulesEngine} from "test/MockMarketplaceRulesEngine.sol";

contract ForteMarketplaceGuardedNFTTest is Test {
    BlacklistOracle internal oracle;
    OperatorRegistry internal operatorRegistry;
    ForteMarketplaceGuardedNFT internal nft;
    MockMarketplaceRulesEngine internal rulesEngine;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xB0B);
    address internal bob = address(0xCAFE);
    address internal operator = address(0xD00D);

    uint256 internal token1;
    uint256 internal token2;

    function setUp() public {
        vm.startPrank(owner);
        oracle = new BlacklistOracle(owner);
        operatorRegistry = new OperatorRegistry(owner);
        nft = new ForteMarketplaceGuardedNFT(owner, address(oracle), address(operatorRegistry), owner);
        rulesEngine = new MockMarketplaceRulesEngine();

        nft.setRulesEngineAddress(address(rulesEngine));
        nft.setCallingContractAdmin(owner);

        token1 = nft.mint(alice);
        token2 = nft.mint(owner);
        vm.stopPrank();
    }

    function testDirectOwnerTransferSucceeds() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, token1);

        assertEq(nft.ownerOf(token1), bob);
    }

    function testUnapprovedOperatorTransferReverts() public {
        vm.prank(alice);
        nft.approve(operator, token1);

        vm.prank(operator);
        vm.expectRevert(bytes("Operator not allowed"));
        nft.transferFrom(alice, bob, token1);
    }

    function testApprovedOperatorTransferSucceeds() public {
        vm.prank(owner);
        operatorRegistry.setAllowedOperator(operator, true);

        vm.prank(alice);
        nft.approve(operator, token1);

        vm.prank(operator);
        nft.transferFrom(alice, bob, token1);

        assertEq(nft.ownerOf(token1), bob);
    }

    function testBlacklistStillBlocksApprovedOperator() public {
        vm.startPrank(owner);
        operatorRegistry.setAllowedOperator(operator, true);
        oracle.setBlacklisted(bob, true);
        vm.stopPrank();

        vm.prank(alice);
        nft.approve(operator, token1);

        vm.prank(operator);
        vm.expectRevert(bytes("Blacklisted address"));
        nft.transferFrom(alice, bob, token1);
    }

    function testPauseBlocksApprovedOperator() public {
        vm.startPrank(owner);
        operatorRegistry.setAllowedOperator(operator, true);
        nft.setTransfersPaused(true);
        vm.stopPrank();

        vm.prank(alice);
        nft.approve(operator, token1);

        vm.prank(operator);
        vm.expectRevert(bytes("Transfers paused"));
        nft.transferFrom(alice, bob, token1);
    }

    function testTreasuryBypassesOperatorGateAndPause() public {
        vm.prank(owner);
        nft.setTransfersPaused(true);

        vm.prank(owner);
        nft.transferFrom(owner, bob, token2);

        assertEq(nft.ownerOf(token2), bob);
    }

    function testSafeTransferWithApprovedOperatorSucceeds() public {
        vm.prank(owner);
        operatorRegistry.setAllowedOperator(operator, true);

        vm.prank(alice);
        nft.approve(operator, token1);

        vm.prank(operator);
        nft.safeTransferFrom(alice, bob, token1, bytes("marketplace"));

        assertEq(nft.ownerOf(token1), bob);
    }
}
