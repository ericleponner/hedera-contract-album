import hello_world.HelloWorld;
import hts.HTSv2;
import test_error.TestError;

public class Main {

    public static void main(String[] args) throws Exception {
        HelloWorld.deploy();
        HTSv2.deploy();
        TestError.deploy();
    }
}
