package hello_library;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import common.Utils;

public class HelloLibrary {

    public static void main(String[] args) throws Exception {
        deployContract();
    }

    public static void deployContract() throws Exception {
        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {};

        Utils.deploy("HelloLibrary", "HelloLibrary", null, executions, HelloLibrary.class);
    }
}
