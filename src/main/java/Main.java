import hello_swarm.HelloSwarm;
import hello_world.HelloWorld;
import hts.HTSv2;
import test_error.TestError;
import test_event.TestEvent;

public class Main {

    public static void main(String[] args) throws Exception {
        HelloSwarm.deploy();
        HelloWorld.deploy();
        HTSv2.deploy();
        TestError.deploy();
        TestEvent.deploy();
    }
}
