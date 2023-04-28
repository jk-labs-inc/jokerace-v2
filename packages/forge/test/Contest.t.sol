// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@forge-std/Test.sol";
import "../src/Contest.sol";

contract ContestTest is Test {
    Contest public contest;
    uint64 public constant CONTEST_START = 1681650000;
    uint64 public constant VOTING_DELAY = 10000;
    uint64 public constant VOTING_PERIOD = 10000;
    uint64 public constant NUM_ALLOWED_PROPOSAL_SUBMISSIONS = 2;
    uint64 public constant MAX_PROPOSAL_COUNT = 100;
    uint64 public constant DOWNVOTING_ALLOWED = 0;
    uint256 public constant ONE_ETH_IN_WEI = 1000000000000000000;
    uint256[] public numParams = [
        CONTEST_START,
        VOTING_DELAY,
        VOTING_PERIOD,
        NUM_ALLOWED_PROPOSAL_SUBMISSIONS,
        MAX_PROPOSAL_COUNT,
        DOWNVOTING_ALLOWED
    ];

    /*
        For this merkle tree:
        {
            "decimals": 18,
            "airdrop": {
                "0x016C8780e5ccB32E5CAA342a926794cE64d9C364": 10,
                "0x185a4dc360ce69bdccee33b3784b0282f7961aea": 100
            }
        }
    */
    bytes32 public constant SUB_AND_VOTING_MERKLE_ROOT =
        bytes32(0xd0aa6a4e5b4e13462921d7518eebdb7b297a7877d6cfe078b0c318827392fb55);
    address public constant PERMISSIONED_ADDRESS_1 = 0x016C8780e5ccB32E5CAA342a926794cE64d9C364;
    address public constant PERMISSIONED_ADDRESS_2 = 0x185a4dc360CE69bDCceE33b3784B0282f7961aea;
    address public constant UNPERMISSIONED_ADDRESS_1 = 0xd698e31229aB86334924ed9DFfd096a71C686900;
    bytes32[] public proof1 = [bytes32(0x005a0033b5a1ac5c2872d7689e0f064ad6d2287ab98439e44c822e1c46530033)];
    bytes32[] public proof2 = [bytes32(0xceeae64152a2deaf8c661fccd5645458ba20261b16d2f6e090fe908b0ac9ca88)];

    address[] public safeSigners = [address(0)];
    uint8 public constant SAFE_THRESHOLD = 1;

    IGovernor.ProposalCore public firstProposalPA1 = IGovernor.ProposalCore({
        author: PERMISSIONED_ADDRESS_1,
        description: "firstProposalPA1",
        exists: true,
        targetMetadata: IGovernor.TargetMetadata({targetAddress: PERMISSIONED_ADDRESS_1}),
        safeMetadata: IGovernor.SafeMetadata({signers: safeSigners, threshold: SAFE_THRESHOLD})
    });
    IGovernor.ProposalCore public secondProposalPA1 = IGovernor.ProposalCore({
        author: PERMISSIONED_ADDRESS_1,
        description: "secondProposalPA1",
        exists: true,
        targetMetadata: IGovernor.TargetMetadata({targetAddress: PERMISSIONED_ADDRESS_2}),
        safeMetadata: IGovernor.SafeMetadata({signers: safeSigners, threshold: SAFE_THRESHOLD})
    });
    IGovernor.ProposalCore public firstProposalPA2 = IGovernor.ProposalCore({
        author: PERMISSIONED_ADDRESS_2,
        description: "firstProposalPA2",
        exists: true,
        targetMetadata: IGovernor.TargetMetadata({targetAddress: PERMISSIONED_ADDRESS_2}),
        safeMetadata: IGovernor.SafeMetadata({signers: safeSigners, threshold: SAFE_THRESHOLD})
    });
    IGovernor.ProposalCore public unpermissionedAuthorProposal1 = IGovernor.ProposalCore({
        author: UNPERMISSIONED_ADDRESS_1,
        description: "unpermissionedAuthorProposal1",
        exists: true,
        targetMetadata: IGovernor.TargetMetadata({targetAddress: PERMISSIONED_ADDRESS_1}),
        safeMetadata: IGovernor.SafeMetadata({signers: safeSigners, threshold: SAFE_THRESHOLD})
    });

    function setUp() public {
        vm.prank(PERMISSIONED_ADDRESS_1);

        contest = new Contest("test",
                              "hello world",
                              SUB_AND_VOTING_MERKLE_ROOT,
                              SUB_AND_VOTING_MERKLE_ROOT,
                              numParams);
    }

    // GOVERNOR SETTINGS

    function testContestStart() public {
        assertEq(contest.contestStart(), CONTEST_START);
    }

    function testVotingDelay() public {
        assertEq(contest.votingDelay(), VOTING_DELAY);
    }

    function testVotingPeriod() public {
        assertEq(contest.votingPeriod(), VOTING_PERIOD);
    }

    function testNumAllowedProposalSubmissions() public {
        assertEq(contest.numAllowedProposalSubmissions(), NUM_ALLOWED_PROPOSAL_SUBMISSIONS);
    }

    function testMaxProposalCount() public {
        assertEq(contest.maxProposalCount(), MAX_PROPOSAL_COUNT);
    }

    function testDownvotingAllowed() public {
        assertEq(contest.downvotingAllowed(), DOWNVOTING_ALLOWED);
    }

    function testCreator() public {
        assertEq(contest.creator(), PERMISSIONED_ADDRESS_1);
    }

    // PROPOSING AND VOTING

    function testValidate() public {
        vm.prank(PERMISSIONED_ADDRESS_1);
        bool validated = contest.validateProposalData(firstProposalPA1);

        assertEq(validated, true);
    }

    function testPropose() public {
        vm.warp(1681650001);
        vm.prank(PERMISSIONED_ADDRESS_1);
        uint256 proposalId = contest.propose(firstProposalPA1, proof1);

        assertEq(proposalId, 15258975670772814556071403711766991884286016301895103318170288180735769227159);
    }

    function testProposeWithoutProof() public {
        vm.warp(1681650001);
        vm.startPrank(PERMISSIONED_ADDRESS_1);
        uint256 firstProposalId = contest.propose(firstProposalPA1, proof1);
        uint256 secondProposalId = contest.proposeWithoutProof(secondProposalPA1);
        vm.stopPrank();

        assertEq(firstProposalId, 15258975670772814556071403711766991884286016301895103318170288180735769227159);
        assertEq(secondProposalId, 108189191310393546759417693285315713017966124403504491979578796487893421625041);
    }

    function testProposeAuthorIsntSender() public {
        vm.warp(1681650001);
        vm.prank(PERMISSIONED_ADDRESS_1);
        vm.expectRevert(bytes("Governor: the proposal author must be msg.sender"));
        contest.propose(unpermissionedAuthorProposal1, proof1);
    }

    function testProposeWithoutProofAuthorIsntSender() public {
        vm.warp(1681650001);
        vm.prank(PERMISSIONED_ADDRESS_1);
        contest.propose(firstProposalPA1, proof1);
        vm.prank(PERMISSIONED_ADDRESS_1);
        vm.expectRevert(bytes("Governor: the proposal author must be msg.sender"));
        contest.proposeWithoutProof(unpermissionedAuthorProposal1);
    }

    function testVote() public {
        vm.startPrank(PERMISSIONED_ADDRESS_1);

        vm.warp(1681650001);
        uint256 proposalId = contest.propose(firstProposalPA1, proof1);
        vm.warp(1681660001);
        uint256 totalVotes = contest.castVote(proposalId, 0, 10 * ONE_ETH_IN_WEI, 1 * ONE_ETH_IN_WEI, proof1);

        vm.stopPrank();

        assertEq(totalVotes, 10 * ONE_ETH_IN_WEI);
    }

    function testVoteWithoutProof() public {
        vm.startPrank(PERMISSIONED_ADDRESS_1);

        vm.warp(1681650001);
        uint256 proposalId = contest.propose(firstProposalPA1, proof1);
        vm.warp(1681660001);
        contest.castVote(proposalId, 0, 10 * ONE_ETH_IN_WEI, 1 * ONE_ETH_IN_WEI, proof1);
        uint256 totalVotesWithoutProof = contest.castVoteWithoutProof(proposalId, 0, 1 * ONE_ETH_IN_WEI);

        vm.stopPrank();

        assertEq(totalVotesWithoutProof, 10 * ONE_ETH_IN_WEI);
    }
}