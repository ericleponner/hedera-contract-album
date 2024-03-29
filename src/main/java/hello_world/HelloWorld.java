package hello_world;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import common.Utils;
import common.Verify;
import common.VerifyV2;

import java.util.Collections;
import java.util.List;

public class HelloWorld {

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

        Utils.deploy("HelloWorld", "HelloWorld", params, executions, HelloWorld.class);
    }

    public static void verify() throws Exception {
        Verify.run("0.0.52787", "HelloWorld", "HelloWorld", Collections.emptyList(), HelloWorld.class);
    }

    public static void verifyV2() throws Exception {
        VerifyV2.run("0.0.48645", "HelloWorld", "HelloWorld", "0.8.17+commit.8df45f5f",
                Collections.emptyList(), HelloWorld.class);
    }
}
