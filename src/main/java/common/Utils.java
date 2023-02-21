package common;

import com.hedera.hashgraph.sdk.*;
import io.github.cdimascio.dotenv.Dotenv;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Date;

public class Utils {

    public static void main(String[] args) {
        System.out.println(System.getProperty("user.dir"));
    }

    public static void deploy(String baseName, String contractName,
                              ContractFunctionParameters params,
                              ContractExecuteTransaction[] executions,
                              Class<?> klass) throws Exception {
        assert(baseName != null);
        assert(contractName != null);

        // 1) Reads byte code and compiler version
        final String byteCode = readResourceString(baseName + "_sol_" + contractName + ".bin", klass);
        final String compilerVersion = readResourceString(baseName + ".ver", klass).trim();

        // 2) Creates Client
        final Client client = createClient();
        final String hederaNetwork = getHederaNetwork();

        // 3) Deploys contract
        final String memo = baseName + ".sol + solcjs " + compilerVersion;
        final ContractCreateFlow createContract = new ContractCreateFlow()
                .setBytecode(byteCode)
                .setContractMemo(memo)
                .setGas(2_000_000);
        if (params != null) {
            createContract.setConstructorParameters(params);
        }

        final TransactionResponse response = createContract.execute(client);
        final TransactionReceipt receipt = response.getReceipt(client);
        final ContractId contractId = receipt.contractId;
        assert(contractId != null);

        // 4) Executes contract
        if (executions != null) {
            for (ContractExecuteTransaction e : executions) {
                e.setContractId(contractId);
                e.setGas(2_000_000);
                e.execute(client);
            }
        }

        // 5) Logs deployment
        final String logRecord = new Date() + " " + hederaNetwork + " " + contractId + " " + contractName + "\n";
        writeToLog(logRecord);

        // 6) UX
        if (receipt.status == Status.SUCCESS) {
            System.out.println(baseName + ".sol deployed successfully to contract " + contractId + " (" + hederaNetwork + ")");
        } else {
            System.out.println(baseName + ".sol deployment failed with status " + receipt.status);
        }
    }

    public static AccountId createAccount() throws Exception {

        // 1) Creates client
        final Client client = createClient();
        final String hederaNetwork = getHederaNetwork();

        // 2) Creates account
        final TransactionResponse response = new AccountCreateTransaction()
                .setKey(getOperatorPublicKey())
                .setInitialBalance(Hbar.from(100))
                .execute(client);
        final TransactionReceipt receipt = response.getReceipt(client);
        final AccountId result = receipt.accountId;
        assert(result != null);

        // 3) Logs
        final String logRecord = new Date() + " " + hederaNetwork + " " + result + " Account\n";
        writeToLog(logRecord);

        return result;
    }

    public static TokenId createToken() throws Exception {

        // 1) Creates client
        final Client client = createClient();
        final String hederaNetwork = getHederaNetwork();
        final PublicKey operatorPublicKey = getOperatorPublicKey();

        // 2) Creates token
        final TransactionResponse response = new TokenCreateTransaction()
                .setTokenSymbol("LFLG")
                .setTokenName("Grenoble Le Versoud")
                .setTokenMemo("Created by hedera-contract-album")
                .setTokenType(TokenType.FUNGIBLE_COMMON)
                .setDecimals(2)
                .setInitialSupply(10000)
                .setTreasuryAccountId(getOperatorId())
                .setSupplyKey(operatorPublicKey)
                .execute(client);
        final TransactionReceipt receipt = response.getReceipt(client);
        final TokenId result = receipt.tokenId;
        assert(result != null);

        // 3) Logs
        final String logRecord = new Date() + " " + hederaNetwork + " " + result + " Token\n";
        writeToLog(logRecord);

        return result;
    }


    //
    // Private
    //

    private static Client createClient() {

        final String envPath = System.getProperty("user.home") + "/.env";
        final Dotenv dotEnv = Dotenv.configure().directory(envPath).load();
        AccountId operatorId = AccountId.fromString(dotEnv.get("OPERATOR_ACCOUNT_ID"));
        PrivateKey operatorKey = PrivateKey.fromString(dotEnv.get("OPERATOR_KEY"));
        String hederaNetwork = dotEnv.get("HEDERA_NETWORK");
        Client client = Client.forName(hederaNetwork);
        client.setOperator(operatorId, operatorKey);

        return client;
    }

    public static AccountId getOperatorId() {
        final String envPath = System.getProperty("user.home") + "/.env";
        final Dotenv dotEnv = Dotenv.configure().directory(envPath).load();
        return AccountId.fromString(dotEnv.get("OPERATOR_ACCOUNT_ID"));
    }

    private static PublicKey getOperatorPublicKey() {
        final String envPath = System.getProperty("user.home") + "/.env";
        final Dotenv dotEnv = Dotenv.configure().directory(envPath).load();
        PrivateKey operatorKey = PrivateKey.fromString(dotEnv.get("OPERATOR_KEY"));
        return operatorKey.getPublicKey();
    }

    private static String getHederaNetwork() {
        final String envPath = System.getProperty("user.home") + "/.env";
        final Dotenv dotEnv = Dotenv.configure().directory(envPath).load();
        return dotEnv.get("HEDERA_NETWORK");
    }

    private static String readResourceString(String resourceName, Class<?> klass) throws IOException {
        final byte[] bytes;
        try (InputStream is = klass.getResourceAsStream(resourceName)) {
            assert (is != null);
            bytes = is.readAllBytes();
        }
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private static void writeToLog(String record) throws Exception {
        final Path logPath = Path.of(System.getProperty("user.dir"), "deployment.log");
        Files.writeString(logPath,record, StandardOpenOption.APPEND);
    }
}
