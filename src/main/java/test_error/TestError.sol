// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

error SimpleError();
error ComplexError(string name, int256 temperature);

// https://blog.soliditylang.org/2021/04/21/custom-errors/

contract TestError {

    function revertSimpleError() public pure{
        revert SimpleError();
    }

    function revertComplexError(string memory name, int256 temperature) public pure {
        revert ComplexError(name, temperature);
    }

}
