pragma solidity ^0.4.25;

// from: https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/math/SafeMath.sol
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "Flawed input for multiplication");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Can't divide by zero");
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Can't subtract a number from a smaller one with uints");
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Result has to be bigger than both summands");

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "Can't perform modulo with zero");
        return a % b;
    }

    function sqrt(uint256 a) public pure returns (uint256) {
        if (a == 0) return 0;

        require(a + 1 > a, "Flawed input for sqrt");

        uint256 c = (a + 1) / 2;
        uint256 b = a;

        while (c < b) {
            b = c;
            c = (a / c + c) / 2;
        }

        return c;
    }
}