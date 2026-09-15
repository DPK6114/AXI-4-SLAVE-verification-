class axi_env extends uvm_env;

	`uvm_component_utils(axi_env)

	axi_scoreboard scb;
	axi_master_agent m_agent;
	axi_slave_agent s_agent;



	function new(string name="axi_env",uvm_component parent);
		super.new(name,parent);
	endfunction


	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		scb=axi_scoreboard::type_id::create("scb",this);
		m_agent=axi_master_agent::type_id::create("m_agent",this);
		s_agent=axi_slave_agent::type_id::create("s_agent",this);
	endfunction


	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		m_agent.m_mon1.mon1_port.connect(scb.master_export);
                s_agent.s_mon1.mon_port.connect(scb.slave_export);
	endfunction


endclass



