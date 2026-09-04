class axi_master_sequencer extends uvm_sequencer#(axi_seq_item);

	`uvm_component_utils(axi_master_sequencer)


	function new(string name="axi_master_sequencer",uvm_component parent);
		super.new(name,parent);
	endfunction

endclass
