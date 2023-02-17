package hts;

import common.Utils;

public class HTSv2 {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        Utils.deploy("HTSv2", "HTS", null, null,  HTSv2.class);
    }

}
