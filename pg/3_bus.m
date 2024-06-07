
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
	1	 2	 200	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	2	 3	 270	 0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
	3	 2	 150     0.0	 0.0	 0.0	 1	    1.00000	    0.00000	 230.0	 1	    1.10000	    0.90000;
];

%% generator data
%% Q== zero because DC-OPF
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin
mpc.gen = [
	1	 185.0	 0.0	 0.0	 0.0	 1.0	 100.0	 1	 300.0	 0.0;
	2	 185.0	 0.0	 0.0	 0.0	 1.0	 100.0	 1	 300.0	 0.0;
	3	 185.0	 0.0	 0.0	 0.0	 1.0	 100.0	 1	 300.0	 0.0;
];

%% generator cost data
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	 0.0	 0.0	 2	  32.0	   0.000000;
	2	 0.0	 0.0	 2	  58.0     0.000000;
	2	 0.0	 0.0	 2	  60.0	   0.000000;
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
	1	 2	 0.0   0.02	 0.0	 200.0	 200.0	 200.0	 0.0	 0.0	 1	 -30.0	 30.0;
	2	 3	 0.0   0.02	 0.0	 200.0	 200.0	 200.0	 0.0	 0.0	 1	 -30.0	 30.0;
];


%% generator_name
mpc.generator_name = {
	'Coal';
	'Biomass';
	'Oil';
};

% INFO    : === Translation Options ===
% INFO    : Phase Angle Bound:           30.0 (deg.)
% INFO    : Line Capacity Model:         stat
% INFO    : Setting Flat Start
% INFO    : Line Capacity PAB:           15.0 (deg.)
% INFO    : 
% INFO   
% INFO    : === Writing Matpower Case File Notes ===
