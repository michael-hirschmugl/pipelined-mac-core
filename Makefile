.PHONY: sim clean

sim:
	@mkdir -p sim
	verilator -Wall --trace --binary \
		-o mac_sim \
		rtl/mac.sv tb/tb_mac.sv
	@./obj_dir/mac_sim

clean:
	@rm -rf obj_dir sim
