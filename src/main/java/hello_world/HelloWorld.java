package hello_world;

import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import common.Utils;

public class HelloWorld {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractFunctionParameters params = new ContractFunctionParameters()
                .addString("Hello World");
        Utils.deploy("HelloWorld", "HelloWorld", params, HelloWorld.class);
    }
}
