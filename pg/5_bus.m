
%
function mpc = pglib_opf_case5_pjm
mpc.version = '2';
mpc.baseMVA = 100.0;


%% area data
%	area	refbus
mpc.areas = [
	1	 2;
];

%% bus data
%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
mpc.bus = [
	1	 2	 318	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	2	 3	 318	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	3	 2	 54		 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	4	 2	 332	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	5	 2	 690	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
];

%% generator data
%% Q== zero because DC-OPF
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin 		
mpc.gen = [
	1	 0	 0.0	 0.0	 0.0	 1.0	 100.0	 1	 422	 0;
	2	 0	 0.0	 0.0	 0.0	 1.0	 100.0	 1	 419	 0;
	3	 0	 0.0	 0.0	 0.0	 1.0	 100.0	 1	 860	 0;
	4	 0	 0.0	 0.0	 0.0	 1.0	 100.0	 1	 325	 0;
	5	 0	 0.0	 0.0	 0.0	 1.0	 100.0	 1	 480     0;
]
		
%% generator cost data
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	 0.0	 0.0	 2	  35.0    			0.000000;
	2	 0.0	 0.0	 2	  32.0	   			0.000000;
	2	 0.0	 0.0	 2	  35.0	   			0.000000;
	2	 0.0	 0.0	 2	  35.0	   			0.000000;
	2	 0.0	 0.0	 2	  35.0	   			0.000000;
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
	1	2	 0.0   0.02	 0.0	400.0	400.0	 4000	 0.0	 0.0	 1	 -30.0	 30.0;
	2	4	 0.0   0.02	 0.0	1620 	1620	 1620	 0.0	 0.0	 1	 -30.0	 30.0;
	3	4	 0.0   0.02	 0.0	220		220	 	 220	 0.0	 0.0	 1	 -30.0	 30.0;
	4	5	 0.0   0.02	 0.0	1520	1520	 1520	 0.0	 0.0	 1	 -30.0	 30.0;
];


%% generator_name
mpc.generator_name = {
	'Coal';
	'Oil';
	'Nuclear';
	'Biomass';
	'Waste';
};

