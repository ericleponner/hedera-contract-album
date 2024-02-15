// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

error SimpleError();
error ComplexError(string name, int256 temperature);

// https://blog.soliditylang.org/2021/04/21/custom-errors/

contract TestEvent {

    event FlightEvent(string indexed phase, int airspeed, int verticalSpeed);

    function flight() public {
        emit FlightEvent("Holding point", 0, 0);
        emit FlightEvent("Taking Off", 110, 0);
        emit FlightEvent("Climbing", 150, 500);
        emit FlightEvent("Cruising", 200, 0);
        emit FlightEvent("Descending", 200, -500);
        emit FlightEvent("Landing", 130, -250);
        emit FlightEvent("Runway Cleared", 10, 0);
    }

}
