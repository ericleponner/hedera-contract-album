package hello_world;

import common.Utils;

public class HelloWorld {

    public static void main(String[] args) throws Exception {
        deploy();
    }

    public static void deploy() throws Exception {
        Utils.deploy("HelloWorld", "HelloWorld", HelloWorld.class);
    }
}
