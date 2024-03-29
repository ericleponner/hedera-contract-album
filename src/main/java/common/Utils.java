package common;

import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonReader;

import com.hedera.hashgraph.sdk.*;
import io.github.cdimascio.dotenv.Dotenv;

import java.io.IOException;
import java.io.InputStream;
import java.io.StringReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
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
        final String byteCode = readResourceString("artifacts/" + contractName + ".bin", klass);
        final String compilerVersion = readCompilerVersionFromMetadata("artifacts/" + contractName + "_meta.json", klass).trim();

        // 2) Creates Client
        final Client client = createClient();
        final String hederaNetwork = getHederaNetwork();

        // 3) Deploys contract
        final String memo = baseName + ".sol + solc " + compilerVersion;
        final ContractCreateFlow createContract = new ContractCreateFlow()
                .setBytecode(byteCode)
                .setContractMemo(memo)
                .setGas(2_000_000)
                .setMaxChunks(40);
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
        PrivateKey operatorKey = PrivateKey.fromStringDER(dotEnv.get("OPERATOR_KEY"));
        String hederaNetwork = dotEnv.get("HEDERA_NETWORK");
        Client client = Client.forName(hederaNetwork);
        client.setOperator(operatorId, operatorKey);
        // Not sure the two lines below are really needed ... but who knows ...
        client.setRequestTimeout(client.getRequestTimeout().multipliedBy(3));
        client.setMaxAttempts(client.getMaxAttempts() * 3);

        System.out.println("Connecting to " + hederaNetwork);
        System.out.println("Operator Account Id: " + operatorId);
        System.out.println("Operator Public Key: " + operatorKey.getPublicKey());

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

    public static String readResourceString(String resourceName, Class<?> klass) throws IOException {
        final byte[] bytes;
        try (InputStream is = klass.getResourceAsStream(resourceName)) {
            assert (is != null);
            bytes = is.readAllBytes();
        }
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private static String readCompilerVersionFromMetadata(String resourceName, Class<?> klass) throws IOException {
        final String result;
        final String jsonText = readResourceString(resourceName, klass);
        try (final JsonReader jsonReader = Json.createReader(new StringReader(jsonText))) {
            final JsonObject o = jsonReader.readObject();
            result = o.get("compiler").asJsonObject().getString("version");
        }
        return result;
    }

    private static void writeToLog(String record) throws Exception {
        final Path logPath = Path.of(System.getProperty("user.dir"), "deployment.log");
        Files.writeString(logPath,record, StandardOpenOption.APPEND);
    }
}
