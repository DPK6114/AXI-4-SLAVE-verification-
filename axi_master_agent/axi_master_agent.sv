class axi_master_agent extends uvm_agent;

	`uvm_component_utils(axi_master_agent)


	axi_master_sequencer m_seqr;
	axi_master_driver m_drv;
	axi_master_monitor m_mon1;

	function new(string name="axi_master_agent",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		m_seqr=axi_master_sequencer::type_id::create("m_seqr",this);
		m_drv=axi_master_driver::type_id::create("m_drv",this);
		m_mon1=axi_master_monitor::type_id::create("m_mon1",this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
                m_drv.seq_item_port.connect(m_seqr.seq_item_export);
	endfunction


endclass
