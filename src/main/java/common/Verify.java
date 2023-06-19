package common;

import com.hedera.hashgraph.sdk.ContractId;
import io.github.cdimascio.dotenv.Dotenv;

import javax.json.Json;
import javax.json.JsonObjectBuilder;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.List;

import static common.Utils.readResourceString;

public class Verify {

    public static void run(String contractId,
                           String baseName, String contractName,
                           List<String> importNames,
                           Class<?> klass) throws Exception {
        assert(contractId != null);
        assert(baseName != null);

        final String requestBody =  makeRequestBody(contractId, baseName, contractName, importNames, klass);

        System.out.println("requestBody=" + requestBody);

        //
        // https://docs.sourcify.dev/docs/api/server/verify/
        //

        final String SOURCIFY_SERVER_URL = "https://sourcify.simonvienot.fr/server";
        final URL url = new URL(SOURCIFY_SERVER_URL + "/verify");
        final HttpURLConnection c = (HttpURLConnection) url.openConnection();
        c.setRequestMethod("POST");
        c.setDoOutput(true);
        c.setRequestProperty("Content-Type", "application/json");
        writeToOutputString(c.getOutputStream(), requestBody);
        final int status = c.getResponseCode();
        System.out.println("status=" + status);
        if (status > 299) {
            System.out.println("error=" + readFromInputStream(c.getErrorStream()));
        } else {
            System.out.println("content=" + readFromInputStream(c.getInputStream()));
        }
        c.disconnect();
    }


    private static String readFromInputStream(InputStream s) throws IOException {
        final StringBuilder result = new StringBuilder();
        try (BufferedReader in = new BufferedReader(new InputStreamReader(s))) {
            String inputLine = in.readLine();
            while (inputLine != null) {
                result.append(inputLine);
                inputLine = in.readLine();
            }
        }
        return result.toString();
    }

    private static void writeToOutputString(OutputStream s, String text) throws IOException {
        try (final BufferedWriter w = new BufferedWriter(new OutputStreamWriter(s))) {
            w.write(text);
        }
    }

    private static String makeRequestBody(String contractId,
                                          String baseName,
                                          String contractName,
                                          List<String> importFiles,
                                          Class<?> klass) throws IOException {
        assert(contractId != null);

        final ContractId cid = ContractId.fromString(contractId);
        final String address = cid.toSolidityAddress();
        final String chainID = String.valueOf(findChainID());
        final String contractSource = baseName + ".sol";

        final String metadata = readResourceString("artifacts/" + contractName + "_meta.json", klass);

        //
        // https://docs.sourcify.dev/docs/api/server/verify/
        //

        final JsonObjectBuilder filesBuilder = Json.createObjectBuilder()
                .add("metadata-1.json", metadata)
                .add(baseName, readResourceString(contractSource, klass));
        for (String f : importFiles) {
            final String fileName = f + ".sol";
            final String content = readResourceString(fileName, klass);
            filesBuilder.add(fileName, content);
        }
        final JsonObjectBuilder builder = Json.createObjectBuilder()
                .add("address", address)
                .add("chain", chainID)
                .add("files", filesBuilder);

        return builder.build().toString();
    }

    private static int findChainID() {
        final int result;

        final String envPath = System.getProperty("user.home") + "/.env";
        final Dotenv dotEnv = Dotenv.configure().directory(envPath).load();
        final String hederaNetwork = dotEnv.get("HEDERA_NETWORK");
        switch(hederaNetwork) {
            case "mainnet":
                result = 0x127;
                break;
            case "testnet":
                result = 0x128;
                break;
            default:
            case "previewnet":
                result = 0x129;
                break;
        }

        return result;
    }
}
