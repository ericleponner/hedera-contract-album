pragma solidity ^0.8.17;

library HelloLibrary {

    function square(uint x) external pure returns (uint) {
        return x*x;
    }
}