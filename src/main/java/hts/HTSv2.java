package hts;

import com.hedera.hashgraph.sdk.AccountId;
import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import com.hedera.hashgraph.sdk.TokenId;
import common.Utils;
import common.VerifyV2;
import hello_world.HelloWorld;

import java.util.Arrays;
import java.util.Collections;

public class HTSv2 {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final TokenId tokenId = Utils.createToken();
        final AccountId accountId = Utils.createAccount();

        ContractExecuteTransaction associateToken = new ContractExecuteTransaction()
                .setGas(2_000_000)
                .setFunction("tokenAssociate", new ContractFunctionParameters()
                        //The account ID to associate the token to
                        .addAddress(accountId.toSolidityAddress())
                        //The token ID to associate to the account
                        .addAddress(tokenId.toSolidityAddress()));

        ContractExecuteTransaction tokenTransfer = new ContractExecuteTransaction()
                .setGas(2_000_000)
                .setFunction("tokenTransfer", new ContractFunctionParameters()
                        .addAddress(tokenId.toSolidityAddress())
                        .addAddress(Utils.getOperatorId().toSolidityAddress())
                        .addAddress(accountId.toSolidityAddress())
                        .addInt64(100));

        ContractExecuteTransaction brokenDissociate = new ContractExecuteTransaction()
                .setGas(2_000_000)
                .setFunction("brokenDissociate");

        final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {
                associateToken, tokenTransfer, brokenDissociate
        };

        Utils.deploy("HTSv2", "HTS", null, executions,  HTSv2.class);
    }

    public static void verifyV2() throws Exception {
        VerifyV2.run("0.0.2665", "HTSv2", "HTS", "0.8.17+commit.8df45f5f",
                Arrays.asList(
                        "HTSv2",
                        "HederaResponseCodes",
                        "HederaTokenService",
                        "IHederaTokenService"
                ), HTSv2.class);
    }

}
