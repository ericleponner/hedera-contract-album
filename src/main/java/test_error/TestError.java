package test_error;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import common.Utils;

public class TestError {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {

        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {
                new ContractExecuteTransaction()
                        .setFunction("revertEmpty"),
                new ContractExecuteTransaction()
                        .setFunction("revertString"),
                new ContractExecuteTransaction()
                        .setFunction("revertSimpleError"),
                new ContractExecuteTransaction()
                        .setFunction("requireFalse"),
                new ContractExecuteTransaction()
                        .setFunction("assertFalse"),
        };

        Utils.deploy("TestError", "TestError", null, executions, test_error.TestError.class);
    }
}
