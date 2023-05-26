package test_error;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import common.Utils;

public class TestError {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractExecuteTransaction execution1 = new ContractExecuteTransaction()
                .setFunction("revertSimpleError");

        final ContractExecuteTransaction execution2 = new ContractExecuteTransaction()
                .setFunction("revertComplexError");

        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {
                execution1, execution2
        };

        Utils.deploy("TestError", "TestError", null, executions, test_error.TestError.class);
    }
}
