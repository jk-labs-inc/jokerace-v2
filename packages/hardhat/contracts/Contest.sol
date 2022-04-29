// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./governance/Governor.sol";
import "./governance/extensions/GovernorSettings.sol";
import "./governance/extensions/GovernorCountingSimple.sol";
import "./governance/extensions/GovernorVotesTimestamp.sol";

contract Contest is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotesTimestamp {
    constructor(string memory _name, IVotesTimestamp _token, uint256[] memory _constructorIntParams, bool _useLinearVoteDecay)
        Governor(_name)
        GovernorSettings(
            _constructorIntParams[0], // _initialContestStart
            _constructorIntParams[1], // _initialVotingDelay, 
            _constructorIntParams[2], // _initialVotingPeriod, 
            _constructorIntParams[3], // _initialContestSnapshot,
            _constructorIntParams[4], // _initialProposalThreshold, 
            _constructorIntParams[5], // _initialNumAllowedProposalSubmissions, 
            _constructorIntParams[6], // _initialMaxProposalCount
            _useLinearVoteDecay
        )
        GovernorVotesTimestamp(_token)
    {}

    // The following functions are overrides required by Solidity.

    function contestStart()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.contestStart();
    }

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function numAllowedProposalSubmissions()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.numAllowedProposalSubmissions();
    }

    function maxProposalCount()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.maxProposalCount();
    }

    function isUsingLinearVoteDecay()
        public
        view
        override(Governor, GovernorSettings)
        returns (bool)
    {
        return super.isUsingLinearVoteDecay();
    }

    function creator()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (address)
    {
        return super.creator();
    }

    function getLinearlyDecayedVotes(address account, uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesTimestamp)
        returns (uint256)
    {
        return super.getLinearlyDecayedVotes(account, blockNumber);
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesTimestamp)
        returns (uint256)
    {
        return super.getVotes(account, blockNumber);
    }

    function getCurrentVotes(address account)
        public
        view
        override(IGovernor, GovernorVotesTimestamp)
        returns (uint256)
    {
        return super.getCurrentVotes(account);
    }
}
