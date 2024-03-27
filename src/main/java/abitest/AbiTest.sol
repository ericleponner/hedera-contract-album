pragma solidity ^0.8.17;

contract AbiTest {

    enum Side { Top, Bottom, Left, Right }

    bool public sampleBool;
    bool[] public sampleBoolArray = [true, true, false];

    int public sampleInt;
    int32 public sampleInt32;
    int[] public sampleIntArray = [-1, 0, 1];

    uint public sampleUInt;
    uint32 public sampleUInt32;
    uint[] public sampleUIntArray = [0, 1, 2];

    address public sampleAddress;
    address[] public sampleAddressArray = [
    0x0001020304050607080900010203040506070809,
    0x0001020304050607080909080706050403020100
    ];

    string public sampleString;
    string[] public sampleStringArray = [
        "Hello",
        "Bonjour",
        "Buenos Dias",
        "Guten Tag"
    ];

    bytes public sampleBytes;
    bytes8 public sampleBytes8;
    bytes[] public sampleBytesArray;
//    bytes[] public sampleBytesArray = [
//        hex"00010203040506070809",
//        hex"09080706050403020100"
//    ];

    Side public sampleEnum;
    Side public defaultSide = Side.Top;
    Side[] public sampleEnumArray = [ Side.Top, Side.Bottom];


    string public message;

    function updateSampleBool(bool newValue) public {
        sampleBool = newValue;
    }

    function updateSampleBoolArray(bool[] memory newValue) public {
        sampleBoolArray = newValue;
    }

    function updateSampleInt(int newValue) public {
        sampleInt = newValue;
    }

    function updateSampleIntArray(int[] memory newValue) public {
        sampleIntArray = newValue;
    }

    function updateSampleInt32(int32 newValue) public {
        sampleInt32 = newValue;
    }

    function updateSampleUInt(uint newValue) public {
        sampleUInt = newValue;
    }

    function updateSampleUIntArray(uint[] memory newValue) public {
        sampleUIntArray = newValue;
    }

    function updateSampleUInt32(uint32 newValue) public {
        sampleUInt32 = newValue;
    }

    function updateSampleAddress(address newValue) public {
        sampleAddress = newValue;
    }

    function updateSampleAddressArray(address[] memory newValue) public {
        sampleAddressArray = newValue;
    }

    function updateSampleString(string calldata newValue) public {
        sampleString = newValue;
    }

    function updateSampleStringArray(string[] memory newValue) public {
        sampleStringArray = newValue;
    }

    function updateSampleBytes(bytes calldata newValue) public {
        sampleBytes = newValue;
    }

    function updateSampleBytesArray(bytes[] memory newValue) public {
        sampleBytesArray = newValue;
    }

    function updateSampleBytes8(bytes8 newValue) public {
        sampleBytes8 = newValue;
    }

    function updateSampleEnum(Side newValue) public {
        sampleEnum = newValue;
    }

    function updateSampleEnumArray(Side[] memory newValue) public {
        sampleEnumArray = newValue;
    }

    function multiply(int v1, int v2) public pure returns (int) {
        return v1 * v2;
    }

}
