from TestSim import TestSim

def main():
    s = TestSim();

    s.runTime(1);

    s.loadTopo("tuna-melt.topo");

    s.loadNoise("no_noise.txt");

    s.bootAll();

    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.TRANSPORT_CHANNEL);

    s.runTime(300);
    s.testServer(1, 41); # server address is public knowledge to all nodes
    s.runTime(60);

    s.hello(4, 'camille', 15);
    s.runTime(20);
    s.hello(8, 'adrian', 5);
    s.runTime(30);
    s.message(4, 15, 'Hello World');
    # s.whisper(4, 'adrian', 'Hello World'); # send message from 4 to "adrian"
    # s.listusr(4);

    # s.clientClose(4, 15, well_known_mote, well_known_port);
    s.runTime(300);



if __name__ == '__main__':
    main()
