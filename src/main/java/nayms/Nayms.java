package nayms;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import common.Utils;
import common.Verify;

import java.util.Collections;

public class Nayms {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractFunctionParameters params = new ContractFunctionParameters()
                .addString("Hello World");
        final ContractFunctionParameters updateParams1 = new ContractFunctionParameters()
                .addString("Bonjour tout le Monde");
        final ContractExecuteTransaction execution1 = new ContractExecuteTransaction()
                .setFunction("update", updateParams1);
        final ContractFunctionParameters updateParams2 = new ContractFunctionParameters()
                .addString("Buenos Dias");
        final ContractExecuteTransaction execution2 = new ContractExecuteTransaction()
                .setFunction("update", updateParams2);
        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {
                execution1, execution2
        };

        Utils.deploy("HelloWorld", "HelloWorld", params, executions, Nayms.class);
    }

    public static void verify() throws Exception {
        Verify.run("0.0.52787", "HelloWorld", "HelloWorld", Collections.emptyList(), Nayms.class);
    }
}
