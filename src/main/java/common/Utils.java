package common;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public class Utils {


    public static void deploy(String baseName, String contractName, Class<?> klass) throws IOException {
        assert(baseName != null);
        assert(contractName != null);

        final String source = readResourceString(baseName + ".sol", klass);
        final String compilerVersion = readResourceString(baseName + ".ver", klass).trim();
        System.out.println(compilerVersion);
        System.out.println(source);
    }

    private static String readResourceString(String resourceName, Class<?> klass) throws IOException {
        final InputStream is = klass.getResourceAsStream(resourceName);
        assert(is != null);
        final byte[] bytes = is.readAllBytes();
        return new String(bytes, StandardCharsets.UTF_8);
    }

}
