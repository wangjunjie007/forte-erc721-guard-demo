// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BlacklistOracle} from "src/BlacklistOracle.sol";
import {ForteGuardedNFT} from "src/ForteGuardedNFT.sol";
import {MockRulesEngine} from "test/MockRulesEngine.sol";

contract ForteGuardedNFTTest is Test {
    BlacklistOracle internal oracle;
    ForteGuardedNFT internal nft;
    MockRulesEngine internal rulesEngine;

    address internal owner = address(0xA11CE);
    address internal alice = address(0xB0B);
    address internal bob = address(0xCAFE);
    address internal charlie = address(0xD00D);

    uint256 internal token1;
    uint256 internal token2;
    uint256 internal token3;

    function setUp() public {
        vm.startPrank(owner);
        oracle = new BlacklistOracle(owner);
        nft = new ForteGuardedNFT(owner, address(oracle), owner);
        rulesEngine = new MockRulesEngine();

        nft.setRulesEngineAddress(address(rulesEngine));
        nft.setCallingContractAdmin(owner);

        token1 = nft.mint(alice);
        token2 = nft.mint(owner);
        token3 = nft.mint(alice);
        vm.stopPrank();
    }

    function testTransferWithinPolicySucceeds() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, token1);

        assertEq(nft.ownerOf(token1), bob);
    }

    function testTransferToBlacklistedRecipientReverts() public {
        vm.prank(owner);
        oracle.setBlacklisted(bob, true);

        vm.prank(alice);
        vm.expectRevert(bytes("Blacklisted address"));
        nft.transferFrom(alice, bob, token1);
    }

    function testTransferFromBlacklistedSenderReverts() public {
        vm.prank(owner);
        oracle.setBlacklisted(alice, true);

        vm.prank(alice);
        vm.expectRevert(bytes("Blacklisted address"));
        nft.transferFrom(alice, bob, token1);
    }

    function testLockupBlocksTransferUntilUnlock() public {
        vm.prank(owner);
        nft.setTokenUnlockTime(token1, block.timestamp + 1 hours);

        vm.prank(alice);
        vm.expectRevert(bytes("Token still locked"));
        nft.transferFrom(alice, bob, token1);

        vm.prank(owner);
        nft.setTokenUnlockTime(token1, 0);

        vm.prank(alice);
        nft.transferFrom(alice, bob, token1);

        assertEq(nft.ownerOf(token1), bob);
    }

    function testEmergencyPauseBlocksTransfer() public {
        vm.prank(owner);
        nft.setTransfersPaused(true);

        vm.prank(alice);
        vm.expectRevert(bytes("Transfers paused"));
        nft.transferFrom(alice, bob, token1);
    }

    function testTreasuryBypassesPauseAndLockup() public {
        vm.startPrank(owner);
        nft.setTransfersPaused(true);
        nft.setTokenUnlockTime(token2, block.timestamp + 1 days);
        nft.transferFrom(owner, bob, token2);
        vm.stopPrank();

        assertEq(nft.ownerOf(token2), bob);
    }

    function testSafeTransferFromRespectsRules() public {
        vm.prank(owner);
        nft.setTransfersPaused(true);

        vm.prank(alice);
        vm.expectRevert(bytes("Transfers paused"));
        nft.safeTransferFrom(alice, bob, token1);
    }

    function testSafeTransferFromWithDataRespectsRules() public {
        vm.prank(owner);
        nft.setTokenUnlockTime(token3, block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert(bytes("Token still locked"));
        nft.safeTransferFrom(alice, bob, token3, bytes("0x1234"));
    }

    function testRulesDisabledAllowsRawTransferBehavior() public {
        vm.startPrank(owner);
        nft.setRulesEngineAddress(address(0));
        oracle.setBlacklisted(bob, true);
        nft.setTransfersPaused(true);
        nft.setTokenUnlockTime(token1, block.timestamp + 1 days);
        vm.stopPrank();

        vm.prank(alice);
        nft.transferFrom(alice, bob, token1);

        assertEq(nft.ownerOf(token1), bob);
    }

    function testTreasuryUpdatedRemovesOwnerBypass() public {
        vm.prank(owner);
        nft.setTreasury(charlie);

        vm.prank(owner);
        nft.setTransfersPaused(true);

        vm.prank(owner);
        vm.expectRevert(bytes("Transfers paused"));
        nft.transferFrom(owner, bob, token2);
    }
}
