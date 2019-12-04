
// Include common routines
#include <stdio.h>
#include <stdlib.h>

#include <memory.h>
#include <assert.h>
#include <iostream>


// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;
// Called by $time in Verilog
double sc_time_stamp () {
    return main_time; // Note does conversion to real, to match SystemC
}

int main(int argc, char** argv) {
	char* pRnd;
	pRnd = getenv("RND");
	assert(pRnd!=NULL);
	int rnd=atoi(pRnd);
	assert(0<=rnd&&rnd<=5);
	printf("================Now for rounding mode: %d=================\n",rnd);

    // Prevent unused variable warnings
    if (0 && argc && argv) {}
    // Pass arguments so Verilated code can see them, e.g. $value$plusargs
    Verilated::commandArgs(argc, argv);

    // Set debug level, 0 is off, 9 is highest presently used
    Verilated::debug(0);

    // Randomization reset policy
    Verilated::randReset(2);

    // Construct the Verilated model, from Vpico5_wrap.h generated from Verilating "pico5_wrap.v"
    TYPE* dut = new TYPE; // Or use a const unique_ptr, or the VL_UNIQUE_PTR wrapper

    // Set some inputs
    dut->rnd = rnd;
    dut->reset = 1;
    dut->clk = 0;
	// Toggle clocks and such
	main_time++; dut->clk = !dut->clk; /*1*/ dut->eval();
	// Toggle clocks and such
	main_time++; dut->clk = !dut->clk; /*0*/ dut->eval();
	// Toggle clocks and such
	main_time++; dut->clk = !dut->clk; /*1*/ dut->eval();
	// Toggle clocks and such
	main_time++; dut->clk = !dut->clk; /*0*/ dut->eval();
    dut->reset = 0;
	while(1) {
		// Toggle clocks and such
		main_time++; dut->clk = !dut->clk; /*1*/ dut->eval();
		// Toggle clocks and such
		main_time++; dut->clk = !dut->clk; /*0*/ dut->eval();
	}

	// Final model cleanup
	dut->final();

	// Destroy model
	delete dut; dut = NULL;

	// Fin
	return 0;

}
