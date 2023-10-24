package uniswap_v3;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import common.Utils;

public class UniSwap_V3 {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {};
        final ContractFunctionParameters params = new ContractFunctionParameters()
                .addString("100"); // amountToMint
        Utils.deploy("TestERC20", "TestERC20", params, executions, UniSwap_V3.class);
    }
}
