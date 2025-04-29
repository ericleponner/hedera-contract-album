package ccip_patch;

import com.hedera.hashgraph.sdk.ContractExecuteTransaction;
import com.hedera.hashgraph.sdk.ContractFunctionParameters;
import common.Utils;

import java.math.BigInteger;

public class CCIP_Patch {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        final ContractFunctionParameters params = new ContractFunctionParameters()
                .addAddress("0x00000000000000000000000000000000004a0873") // 0.0.4851827 KOPECK
                .addAddress("0x00000000000000000000000000000000004a0873") // 0.0.1584
                .addUint256(BigInteger.valueOf(50))
                .addString("https://hashscan.io")
                .addUint256(BigInteger.valueOf(1))
                .addString("CCIP-N")
                .addString("CCIP-S");
       final ContractExecuteTransaction[] executions = new ContractExecuteTransaction[] {};

        Utils.deploy("AssetTokenCCIPCompatiblePatch", "AssetTokenCCIPCompatiblePatch", params, executions, CCIP_Patch.class);
    }
}
