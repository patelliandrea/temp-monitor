generic module RandomReaderC() {
	provides interface Read<uint16_t>;
	uses interface Random;
}

implementation {

	task void generateRandomRead() {
		signal Read.readDone(SUCCESS, call Random.rand16() % 100);
	}

	command error_t Read.read() {
		post generateRandomRead();
		return SUCCESS;
	}

}