package test_error;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import common.Utils;

import java.math.BigInteger;

public class TestError {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractExecuteTransaction execution1 = new ContractExecuteTransaction()
                .setFunction("revertSimpleError");

        final ContractFunctionParameters revertParams = new ContractFunctionParameters()
                .addString("Alexandre Dumas")
                .addInt256(BigInteger.valueOf(-20));
        final ContractExecuteTransaction execution2 = new ContractExecuteTransaction()
                .setFunction("revertComplexError", revertParams);

        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {
                execution1, execution2
        };

        Utils.deploy("TestError", "TestError", null, executions, test_error.TestError.class);
    }
}
