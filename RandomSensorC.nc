generic configuration RandomSensorC() {
	provides interface Read<uint16_t>;
}

implementation {
	components new RandomReaderC();
	components RandomC;

	RandomReaderC = Read;
	RandomReaderC.Random -> RandomC;
}