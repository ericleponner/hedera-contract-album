package test_event;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import common.Utils;

public class TestEvent {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractExecuteTransaction execution = new ContractExecuteTransaction()
                .setFunction("flight");

        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {
                execution
        };

        Utils.deploy("TestEvent", "TestEvent", null, executions, TestEvent.class);
    }
}
