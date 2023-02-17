package common;

import com.hedera.hashgraph.sdk.*;
import io.github.cdimascio.dotenv.Dotenv;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public class Utils {


    public static void deploy(String baseName, String contractName, ContractFunctionParameters params, Class<?> klass) throws Exception {
        assert(baseName != null);
        assert(contractName != null);

        // 1) Reads byte code and compiler version
        final String byteCode = readResourceString(baseName + "_sol_" + baseName + ".bin", klass);
        final String compilerVersion = readResourceString(baseName + ".ver", klass).trim();

        // 2) Creates Client
        final String envPath = System.getProperty("user.home") + "/.env";
        final Dotenv dotEnv = Dotenv.configure().directory(envPath).load();
        AccountId operatorId = AccountId.fromString(dotEnv.get("OPERATOR_ACCOUNT_ID"));
        PrivateKey operatorKey = PrivateKey.fromString(dotEnv.get("OPERATOR_KEY"));
        String hederaNetwork = dotEnv.get("HEDERA_NETWORK");
        Client client = Client.forName(hederaNetwork);
        client.setOperator(operatorId, operatorKey);

        // 3) Deploys contract
        final String memo = baseName + ".sol + solcjs " + compilerVersion;
        final ContractCreateFlow createContract = new ContractCreateFlow()
                .setBytecode(byteCode)
                .setContractMemo(memo)
                .setGas(4_000_000);
        if (params != null) {
            createContract.setConstructorParameters(params);
        }

        final TransactionResponse response = createContract.execute(client);
        final TransactionReceipt receipt = response.getReceipt(client);
        final ContractId contractId = receipt.contractId;

        if (receipt.status == Status.SUCCESS) {
            System.out.println(baseName + ".sol deployed successfully to contract " + contractId + " (" + hederaNetwork + ")");
        } else {
            System.out.println(baseName + ".sol deployment failed with status " + receipt.status);
        }
//
//        System.out.println(operatorId);
//        System.out.println(operatorKey);
//        System.out.println(compilerVersion);
//        System.out.println(byteCode);
    }

    private static String readResourceString(String resourceName, Class<?> klass) throws IOException {
        final InputStream is = klass.getResourceAsStream(resourceName);
        assert(is != null);
        final byte[] bytes = is.readAllBytes();
        return new String(bytes, StandardCharsets.UTF_8);
    }

}
