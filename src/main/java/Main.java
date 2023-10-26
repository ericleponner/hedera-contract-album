import dao.DAO;
import hello_swarm.HelloSwarm;
import hello_world.HelloWorld;
import hts.HTSv2;
import nayms.Nayms;
import test_error.TestError;
import test_event.TestEvent;
import uniswap_v3.UniSwap_V3;

public class Main {

    public static void main(String[] args) throws Exception {
        HelloSwarm.deploy();
        HelloWorld.deploy();
        HTSv2.deploy();
        TestError.deploy();
        TestEvent.deploy();
        Nayms.deploy();
        DAO.deploy();
        UniSwap_V3.deploy();
    }
}
