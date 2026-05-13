module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/Users/santa.ntw/Desktop/4th-Semester/hardware-sys-lab/hw-final/sim_build/filter_engine.fst");
    end
    $dumpvars(0, filter_engine);
end
endmodule
