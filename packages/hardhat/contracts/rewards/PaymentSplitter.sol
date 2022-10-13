// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/utils/SafeERC20.sol";
import "../utils/Address.sol";
import "../utils/Context.sol";
import "../governance/IGovernor.sol";
import "../governance/extensions/GovernorCountingSimple.sol";

/**
 * @title PaymentSplitter
 * @dev This contract allows to split Ether payments among a group of accounts. The sender does not need to be aware
 * that the Ether will be split in this way, since it is handled transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares. Of all the Ether that this contract receives, each account will then be able to claim
 * an amount proportional to the percentage of total shares they were assigned. The distribution of shares is set at the
 * time of contract deployment and can't be updated thereafter.
 *
 * `PaymentSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to the
 * accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the {release}
 * function.
 *
 * NOTE: This contract assumes that ERC20 tokens will behave similarly to native tokens (Ether). Rebasing tokens, and
 * tokens that apply fees during transfers, are likely to not be supported as expected. If in doubt, we encourage you
 * to run tests before sending real value to this contract.
 */
contract PaymentSplitter is Context {
    event PayeeAdded(uint256 ranking, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event ERC20PaymentReleased(IERC20 indexed token, address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);
    event RewardWithdrawn(address by, uint256 amount);
    event ERC20RewardWithdrawn(IERC20 indexed token, address by, uint256 amount);

    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(uint256 => uint256) private _shares;
    mapping(uint256 => uint256) private _released;
    uint256[] private _payees;

    mapping(IERC20 => uint256) private _erc20TotalReleased;
    mapping(IERC20 => mapping(uint256 => uint256)) private _erc20Released;
    
    GovernorCountingSimple private _underlyingContest;
    address private _creator;
    uint256[] private _rankedProposalIds;

    /**
     * @dev Creates an instance of `PaymentSplitter` where each ranking in `payees` is assigned the number of shares at
     * the matching position in the `shares` array.
     *
     * All rankings in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
     * duplicates in `payees`.
     */
    constructor(uint256[] memory payees, uint256[] memory shares_, GovernorCountingSimple underlyingContest_) payable {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }

        _underlyingContest = underlyingContest_;
        _creator = msg.sender;
    }

    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }
    
    /**
     * @dev Getter for the creator of this rewards contract.
     */
    function creator() public view returns (address) {
        return _creator;
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return _totalReleased;
    }

    /**
     * @dev Getter for the total amount of `token` already released. `token` should be the address of an IERC20
     * contract.
     */
    function totalReleased(IERC20 token) public view returns (uint256) {
        return _erc20TotalReleased[token];
    }

    /**
     * @dev Getter for the amount of shares held by a ranking.
     */
    function shares(uint256 ranking) public view returns (uint256) {
        return _shares[ranking];
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(uint256 ranking) public view returns (uint256) {
        return _released[ranking];
    }

    /**
     * @dev Getter for the amount of `token` tokens already released to a payee. `token` should be the address of an
     * IERC20 contract.
     */
    function released(IERC20 token, uint256 ranking) public view returns (uint256) {
        return _erc20Released[token][ranking];
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(uint256 index) public view returns (uint256) {
        return _payees[index];
    }

    /**
     * @dev Getter for the amount of payee's releasable Ether.
     */
    function releasable(uint256 ranking) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased();
        return _pendingPayment(ranking, totalReceived, released(ranking));
    }

    /**
     * @dev Getter for the amount of payee's releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(IERC20 token, uint256 ranking) public view returns (uint256) {
        uint256 totalReceived = token.balanceOf(address(this)) + totalReleased(token);
        return _pendingPayment(ranking, totalReceived, released(token, ranking));
    }

    /**
     * @dev Triggers a transfer to `ranking` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(uint256 ranking) public virtual {
        require(_underlyingContest.state() == IGovernor.ContestState.Completed, "PaymentSplitter: contest must be completed for rewards to be paid out");
        require(_shares[ranking] > 0, "PaymentSplitter: ranking has no shares");

        uint256 payment = releasable(ranking);

        require(payment != 0, "PaymentSplitter: account is not due payment");

        // _totalReleased is the sum of all values in _released.
        // If "_totalReleased += payment" does not overflow, then "_released[account] += payment" cannot overflow.
        _totalReleased += payment;
        unchecked {
            _released[ranking] += payment;
        }

        if (_rankedProposalIds.length == 0) {
            _rankedProposalIds = _underlyingContest.rankedProposals();
        }
        require(ranking < (_rankedProposalIds.length + 1), "PaymentSplitter: there are not enough proposals for that ranking to exist");
        address payable proposalAuthor = payable(_underlyingContest.getProposal(_rankedProposalIds[ranking - 1]).author);

        require(proposalAuthor != address(0), "PaymentSplitter: account is the zero address");

        Address.sendValue(proposalAuthor, payment);
        emit PaymentReleased(proposalAuthor, payment);
    }

    /**
     * @dev Triggers a transfer to `ranking` of the amount of `token` tokens they are owed, according to their
     * percentage of the total shares and their previous withdrawals. `token` must be the address of an IERC20
     * contract.
     */
    function release(IERC20 token, uint256 ranking) public virtual {
        require(_underlyingContest.state() == IGovernor.ContestState.Completed, "PaymentSplitter: contest must be completed for rewards to be paid out");
        require(_shares[ranking] > 0, "PaymentSplitter: account has no shares");

        uint256 payment = releasable(token, ranking);

        require(payment != 0, "PaymentSplitter: account is not due payment");

        // _erc20TotalReleased[token] is the sum of all values in _erc20Released[token].
        // If "_erc20TotalReleased[token] += payment" does not overflow, then "_erc20Released[token][account] += payment"
        // cannot overflow.
        _erc20TotalReleased[token] += payment;
        unchecked {
            _erc20Released[token][ranking] += payment;
        }

        if (_rankedProposalIds.length == 0) {
            _rankedProposalIds = _underlyingContest.rankedProposals();
        }
        require(ranking < (_rankedProposalIds.length + 1), "PaymentSplitter: there are not enough proposals for that ranking to exist");
        address payable proposalAuthor = payable(_underlyingContest.getProposal(_rankedProposalIds[ranking - 1]).author);

        require(proposalAuthor != address(0), "PaymentSplitter: account is the zero address");

        SafeERC20.safeTransfer(token, proposalAuthor, payment);
        emit ERC20PaymentReleased(token, proposalAuthor, payment);
    }

    function withdrawRewards() public virtual {
        require(msg.sender == creator());

        Address.sendValue(payable(creator()), address(this).balance);
        emit RewardWithdrawn(creator(), address(this).balance);
    }

    function withdrawRewards(IERC20 token) public virtual {
        require(msg.sender == creator());

        SafeERC20.safeTransfer(token, payable(creator()), token.balanceOf(address(this)));
        emit ERC20RewardWithdrawn(token, creator(), token.balanceOf(address(this)));
    }

    /**
     * @dev internal logic for computing the pending payment of a `ranking` given the token historical balances and
     * already released amounts.
     */
    function _pendingPayment(
        uint256 ranking,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return (totalReceived * _shares[ranking]) / _totalShares - alreadyReleased;
    }

    /**
     * @dev Add a new payee to the contract.
     * @param ranking The ranking of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function _addPayee(uint256 ranking, uint256 shares_) private {
        require(ranking > 0, "PaymentSplitter: ranking is 0, must be greater");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[ranking] == 0, "PaymentSplitter: account already has shares");
        require(_shares[ranking] == 0, "PaymentSplitter: account already has shares");

        _payees.push(ranking);
        _shares[ranking] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeAdded(ranking, shares_);
    }
}