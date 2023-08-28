package common;

import com.hedera.hashgraph.sdk.ContractId;
import io.github.cdimascio.dotenv.Dotenv;

import javax.json.Json;
import javax.json.JsonObject;
import javax.json.JsonObjectBuilder;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.List;

import static common.Utils.readResourceString;
import static common.Verify.findChainID;
import static common.Verify.readFromInputStream;

public class VerifyV2 {

    public static void run(String contractId,
                           String baseName, String contractName,
                           String compilerVersion,
                           List<String> importNames,
                           Class<?> klass) throws Exception {
        assert(contractId != null);
        assert(baseName != null);

        final String requestBody =  makeRequestBody(contractId, baseName, contractName, compilerVersion, importNames, klass);

        System.out.println("requestBody=" + requestBody);

        //
        // https://sourcify.dev/server/api-docs/#/Stateless%20Verification/post_verify_solc_json
        //

        final String SOURCIFY_SERVER_URL = "https://verify.simonvienot.fr/server";
        final URL url = new URL(SOURCIFY_SERVER_URL + "/verify/solc-json");
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

    private static void writeToOutputString(OutputStream s, String text) throws IOException {
        try (final BufferedWriter w = new BufferedWriter(new OutputStreamWriter(s))) {
            w.write(text);
        }
    }

    private static String makeRequestBody(String contractId,
                                          String baseName,
                                          String contractName,
                                          String compilerVersion,
                                          List<String> importFiles,
                                          Class<?> klass) throws IOException {
        assert(contractId != null);

        final ContractId cid = ContractId.fromString(contractId);
        final String address = cid.toSolidityAddress();
        final String chainID = String.valueOf(findChainID());

        //
        // https://sourcify.dev/server/api-docs/#/Stateless%20Verification/post_verify_solc_json
        //

        final JsonObject solcInput = makeSolcInput(baseName, importFiles, klass);
        System.out.println("solcInput=" + solcInput);

        final JsonObjectBuilder filesBuilder = Json.createObjectBuilder()
                .add("SolcJsonInput.json", solcInput.toString());
        final JsonObjectBuilder builder = Json.createObjectBuilder()
                .add("address", address)
                .add("chain", chainID)
                .add("files", filesBuilder)
                .add("compilerVersion", compilerVersion)
                .add("contractName", contractName);

        return builder.build().toString();
    }

    private static JsonObject makeSolcInput(String baseName,
                                            List<String> importFiles,
                                            Class<?> klass) throws IOException {


        // https://docs.soliditylang.org/en/latest/using-the-compiler.html#input-description

        final String contractSource = baseName + ".sol";
        final JsonObjectBuilder contentBuilder = Json.createObjectBuilder();
        contentBuilder.add("content", readResourceString(contractSource, klass));
        final JsonObjectBuilder sourcesBuilder = Json.createObjectBuilder();
        sourcesBuilder.add(contractSource, contentBuilder);
        for (String f : importFiles) {
            final String fileName = f + ".sol";
            final String content = readResourceString(fileName, klass);
            sourcesBuilder.add(fileName, Json.createObjectBuilder().add("content", content));
        }

        final JsonObjectBuilder builder = Json.createObjectBuilder()
                .add("language", "Solidity")
                .add("sources", sourcesBuilder);

        return builder.build();
    }
}
