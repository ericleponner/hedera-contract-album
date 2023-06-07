package hello_swarm;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import common.Utils;

public class HelloSwarm {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractFunctionParameters params = new ContractFunctionParameters()
                .addString("Hello Swarm");
        final ContractFunctionParameters updateParams1 = new ContractFunctionParameters()
                .addString("Bonjour Swarm");
        final ContractExecuteTransaction execution1 = new ContractExecuteTransaction()
                .setFunction("update", updateParams1);
        final ContractFunctionParameters updateParams2 = new ContractFunctionParameters()
                .addString("Buenos Dias Swarm");
        final ContractExecuteTransaction execution2 = new ContractExecuteTransaction()
                .setFunction("update", updateParams2);
        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {
                execution1, execution2
        };

        Utils.deploy("HelloSwarm", "HelloSwarm", params, executions, HelloSwarm.class);
    }
}
