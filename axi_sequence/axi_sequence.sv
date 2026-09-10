class axi_sequence extends uvm_sequence #(axi_seq_item);

	`uvm_object_utils(axi_sequence)

	function new(string name="axi_sequence");
		super.new(name);
	endfunction


	virtual task body();
		axi_seq_item pkt;
		repeat(1) begin
			pkt=axi_seq_item::type_id::create("pkt");
			wait_for_grant();
			pkt.randomize() with {pkt.AWLEN==9; pkt.AWSIZE==1; pkt.AWBURST==2'b01; pkt.ARESETn==1; pkt.AWADDR==32'h0000_0000;};
			send_request(pkt);
			wait_for_item_done();
			get_response(rsp);
		end
	endtask

endclass




