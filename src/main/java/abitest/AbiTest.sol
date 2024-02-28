pragma solidity ^0.8.17;

contract AbiTest {

    enum Side { Top, Bottom, Left, Right }

    bool public sampleBool;

    int public sampleInt;
    int32 public sampleInt32;

    uint public sampleUInt;
    uint32 public sampleUInt32;

    address public sampleAddress;

    string public sampleString;

    bytes public sampleBytes;
    bytes8 public sampleBytes8;

    Side public sampleEnum;
    Side public defaultSide = Side.Top;

    string public message;

    function updateSampleBool(bool newValue) public {
        sampleBool = newValue;
    }

    function updateSampleInt(int newValue) public {
        sampleInt = newValue;
    }

    function updateSampleInt32(int32 newValue) public {
        sampleInt32 = newValue;
    }

    function updateSampleUInt(uint newValue) public {
        sampleUInt = newValue;
    }

    function updateSampleUInt32(uint32 newValue) public {
        sampleUInt32 = newValue;
    }

    function updateSampleAddress(address newValue) public {
        sampleAddress = newValue;
    }

    function updateSampleString(string calldata newValue) public {
        sampleString = newValue;
    }

    function updateSampleBytes(bytes calldata newValue) public {
        sampleBytes = newValue;
    }

    function updateSampleBytes8(bytes8 newValue) public {
        sampleBytes8 = newValue;
    }

    function multiply(int v1, int v2) public pure returns (int) {
        return v1 * v2;
    }

}
