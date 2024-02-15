package abitest;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import common.Utils;
import common.Verify;

import java.util.Collections;

public class AbiTest {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {};
        final ContractFunctionParameters params = new ContractFunctionParameters();
        Utils.deploy("AbiTest", "AbiTest", params, executions, AbiTest.class);
    }

    public static void verify() throws Exception {
        Verify.run("0.0.1043", "DAO", "DAO", Collections.emptyList(), AbiTest.class);
    }
}
