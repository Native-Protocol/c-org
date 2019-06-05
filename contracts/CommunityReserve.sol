pragma solidity ^0.4.24;

contract CommunityReserve {

    /* The parameters of the Community, based on a set magnitude */
    uint base = 10000;
    uint slope = base; // parametrize the buying linear curve
    uint alpha = base/10; // 10% split into reserve when members/investors buy
    uint beta = base/3; // 33% split into reserve when revenues are deposited

    /* The tokens of the Community */
    mapping(address => uint) internal balances;
    address internal communityFund; // The owner of the contract
    uint internal tokensInCirculation = 0;
    uint internal reserveBalance = 0;

    /* Permission rights */
    modifier isOwner(address sender) { require(sender == communityFund); _; }

    /* Events */
    event UpdateTokens(uint tokensInCirculation, uint reserveBalance);

    /* 
     * Solidity doesn't have floating point decimals so we use a high magnitude
     * base to act as decimal places for more accurate division.
     */
    constructor(uint _base) public {
        communityFund = msg.sender;
        slope = _base;
        alpha = _base/10;
        beta = _base/3;
    }

    /* Getters and setters */
    function setSlope(uint _slope) public isOwner(msg.sender) {
        slope = _slope;
    }
    function setAlpha(uint _alpha) public isOwner(msg.sender) {
        alpha = _alpha;
    }
    function setBeta(uint _beta) public isOwner(msg.sender) {
        beta = _beta;
    }
    function getMyBalance()
        public
        view
        returns (uint y) {
            y = balances[msg.sender];
    }
    function getReserveBalance()
        public
        view
        returns (uint y) {
            y = reserveBalance;
    }
    function getFundBalance()
        public
        view
        returns (uint y) {
            y = balances[communityFund];
    }
    function getTokensInCirculation()
        public
        view
        returns (uint y) {
            y = tokensInCirculation;
    }
    function getPriceFor25()
        public
        view
        returns (uint y) {
            require (tokensInCirculation > 0);
            y = (reserveBalance / (2 * tokensInCirculation * slope / alpha));
    }

    /* Minting and burning tokens */
    // TODO: Protection against overflows
    function buy() public payable {
        require(msg.value > 0);

        // Create tokens
        uint investment = msg.value;
        uint tokenAmount = sqrt(2*investment*base/slope + tokensInCirculation*tokensInCirculation) - tokensInCirculation + 1;
        balances[msg.sender] += tokenAmount;
        tokensInCirculation += tokenAmount;

        // Redistribute tokens
        reserveBalance += alpha*investment;
        communityFund.transfer((base-alpha)/base*investment);

        emit UpdateTokens(tokensInCirculation, reserveBalance);
    }

    function sell(uint tokenAmount) public {
        // Check funds
        require(tokenAmount > 0);
        require(balances[msg.sender] >= tokenAmount);

        balances[msg.sender] -= tokenAmount;
        uint withdraw = reserveBalance*tokenAmount/tokensInCirculation/tokensInCirculation*(2*tokensInCirculation - tokenAmount);
        reserveBalance -= withdraw;
        withdraw /= base;
        msg.sender.transfer(withdraw);

        emit UpdateTokens(tokensInCirculation, reserveBalance);
    }

    // TODO: The balance update and transfer to the community fund smell fishy
    function pay()
        public
        payable {

        require(msg.value > 0);
        uint revenue = msg.value;
        // Create tokens
        // TODO: Why are tokens being minted here?
        uint tokenAmount = sqrt(2*revenue*base/slope + tokensInCirculation*tokensInCirculation) - tokensInCirculation;
        balances[communityFund] += tokenAmount;
        tokensInCirculation += tokenAmount;

        // Redistribute tokens
        reserveBalance += revenue;
        // TODO: This seems to cause out of gas errors
        communityFund.transfer((1-beta)*revenue/base);

        emit UpdateTokens(tokensInCirculation, reserveBalance);
    }

    function mint(uint amount)
        public
        isOwner(msg.sender) {

        require(amount > 0);
        tokensInCirculation += amount;
    }

    /* Utilities */

    /* Babylonian method for square root. See: https://ethereum.stackexchange.com/a/2913 */
    function sqrt(uint x)
        private
        pure
        returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
