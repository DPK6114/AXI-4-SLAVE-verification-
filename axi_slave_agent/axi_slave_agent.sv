class axi_slave_agent extends uvm_agent;

	`uvm_component_utils(axi_slave_agent)

	axi_slave_monitor s_mon1;


	function new(string name = "axi_slave_agent",uvm_component parent = null);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		s_mon1=axi_slave_monitor::type_id::create("s_mon1",this);
	endfunction


endclass
