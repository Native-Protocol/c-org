pragma solidity ^0.4.24;

contract CommunityReserve {

    /*
     * The parameters of the Community. 
     *
     * Solidity doesn't have floating point variable so we use a high magnitude
     * to act as decimal places for more accurate division.
     */
    uint base = 10000; // the magnitude applied (10^4)
    uint slope = base; // parametrize the buying linear curve
    uint alpha = base/10; // 10% split into reserve when members/investors buy
    uint beta = base/10; // 33% split into reserve when revenues are deposited

    /* The tokens of the Community */
    address internal communityFund; // The owner of the contract
    uint internal tokensInCirculation = 0;
    mapping(address => uint) internal balances;

    /* Permission rights */
    modifier isOwner(address sender) { require(sender == communityFund); _; }

    /* Events */
    event UpdateTokens(uint tokensInCirculation);
    event WithdrawTokens(uint amount);

    /** Constructor */
    constructor(uint _base) public {
        communityFund = msg.sender;
        // Use _base magnitude to set ratios
        slope = _base;
        alpha = _base/10;
        beta = _base/10;
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
            y = address(this).balance;
    }
    function getFundBalance()
        public
        view
        returns (uint y) {
            y = address(communityFund).balance;
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
            require(tokensInCirculation > 0, "There's no curve to derive from");
            y = getReserveBalance() * base / (2 * tokensInCirculation * slope / alpha);
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

        // Send remainder percentage - (base-alpha)/base - to fund.
        communityFund.transfer((base-alpha)*investment/base);

        emit UpdateTokens(tokensInCirculation);
    }

    function sell(uint tokenAmount) public {
        // Check funds
        require(tokenAmount > 0);
        require(balances[msg.sender] >= tokenAmount);

        balances[msg.sender] -= tokenAmount;
        tokensInCirculation -= tokenAmount;

        // TODO: This equation is returning an order of magnitude off and a
        // seemingly incorrect amount. Am getting 162197 should be ~2027760
        uint withdraw = getReserveBalance()*tokenAmount/tokensInCirculation/tokensInCirculation*(2*tokensInCirculation - tokenAmount);

        // emit event for testing
        emit WithdrawTokens(withdraw);
        msg.sender.transfer(withdraw);

        emit UpdateTokens(tokensInCirculation);
    }

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

        // Send remainder percentage - (base-beta)/base - to fund.
        communityFund.transfer((base-beta)*revenue/base);

        emit UpdateTokens(tokensInCirculation);
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