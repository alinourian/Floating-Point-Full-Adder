module fp_adder(
	input [31:0] a,
	input [31:0] b,
	output [31:0] s
	);

	wire [25:0] a_F, b_F;								// Fraction of 'a' and 'b'
	wire [7:0] a_E, b_E;								// Exponent of 'a' and 'b'
	wire borrow; 										// The borrow bit : 1 if a is bigger or equal to b, 0 if b is bigger
	wire [7:0] shift; 									// Small ALU output : the amount of shift for fraction of the smaller one
	wire [25:0] bigger_F, smaller_F;					// The bigger and smaller number
	wire [7:0] bigger_E, smaller_E;						// Exponents of the bigger and smaller number
	wire bigger_S, smaller_S;							// Signs of bigger and smaller number
	wire sticky;										// OR of the bits whith are throw away because of the shift of the smaller number
	wire [26:0] smaller_F_new, bigger_F_new;			// New fractions after shift
	wire [28:0] signed_bigger_F, signed_smaller_F;		// 2's compliment of the fractions
	wire [28:0] bigAlu;									// Big ALU output(Sum of fractions): 3'b(sign,ov,Hidden) + 23'b(fraction) + 3'b(R,G,sticky) = 29'b
	wire [27:0] tempSum;								// Sum of fractions in Sign-Magnitute
	wire [4:0] leadOne;									// The number of the cell of the first 1 of the smaller fraction from left:)
	wire [4:0] leadShift;								// The amount of the shift for smaller exponent : 27 - leadOne
	wire [4:0] shift_s;									// The amount of shift for sum of two fractions
	wire [7:0] tempE;									// Exponent of the sum befor normalizing
	wire [27:0] tempF;									// Fraction of the sum befor normalizing
	wire [23:0] normF_s;								// Normalized fraction (with the hidden bit) of the sum
	wire [24:0] round_F;								// Rouned fraction (with the hidden bit) of the sum
	wire Sign_s;										// Sign of the sum
	wire [7:0] Exponent_s;								// Exponent of the sum
	wire [22:0] Fraction_s;								// Fraction of the sum

	assign a_F = a[30:23] == 0 ? {1'b0, a[22:0], 2'b00} : {1'b1, a[22:0], 2'b00};
	assign b_F = b[30:23] == 0 ? {1'b0, b[22:0], 2'b00} : {1'b1, b[22:0], 2'b00};

	assign a_E = a[30:23] == 0 ? 8'h01 : a[30:23];
	assign b_E = b[30:23] == 0 ? 8'h01 : b[30:23];

	assign borrow = (a_E >= b_E) ? 1'b1 : 1'b0;
	assign shift = borrow ? (a_E + ~b_E + 1) : (b_E + ~a_E + 1);
	
	assign bigger_F = borrow ? a_F : b_F;
	assign smaller_F = borrow ? b_F : a_F;
	assign bigger_E = borrow ? a_E : b_E;
	assign smaller_E = borrow ? b_E : a_E;
	assign bigger_S = borrow ? a[31] : b[31];
	assign smaller_S = borrow ? b[31] : a[31];

	assign sticky = |(smaller_F[25:2]<<(8'h1A + ~shift + 1));
	
	assign bigger_F_new = {bigger_F, 1'b0};
	assign smaller_F_new = {smaller_F>>shift, sticky};

	assign signed_bigger_F[27:0] = bigger_S ? (~{1'b0, bigger_F_new} + 1) : {1'b0, bigger_F_new};
	assign signed_smaller_F[27:0] = smaller_S ? (~{1'b0, smaller_F_new} + 1) : {1'b0, smaller_F_new};
	assign signed_bigger_F[28] = signed_bigger_F[27];
	assign signed_smaller_F[28] = signed_smaller_F[27];
	assign bigAlu = signed_bigger_F + signed_smaller_F;
	
	assign tempSum = bigAlu[28] ? (~bigAlu[27:0] + 1) : bigAlu[27:0];
	
	assign leadOne = tempSum[27] ? 5'h1B :
				tempSum[26] ? 5'h1A :
				tempSum[25] ? 5'h19 :
				tempSum[24] ? 5'h18 :
				tempSum[23] ? 5'h17 :
				tempSum[22] ? 5'h16 :
				tempSum[21] ? 5'h15 :
				tempSum[20] ? 5'h14 :
				tempSum[19] ? 5'h13 :
				tempSum[18] ? 5'h12 :
				tempSum[17] ? 5'h11 :
				tempSum[16] ? 5'h10 :
				tempSum[15] ? 5'h0F :
				tempSum[14] ? 5'h0E :
				tempSum[13] ? 5'h0D :
				tempSum[12] ? 5'h0C :
				tempSum[11] ? 5'h0B :
				tempSum[10] ? 5'h0A :
				tempSum[9] ? 5'h09 :
				tempSum[8] ? 5'h08 :
				tempSum[7] ? 5'h07 :
				tempSum[6] ? 5'h06 :
				tempSum[5] ? 5'h05 :
				tempSum[4] ? 5'h04 :
				tempSum[3] ? 5'h03 :
				tempSum[2] ? 5'h02 :
				tempSum[1] ? 5'h01 :
				5'h00;
	
	assign leadShift = 5'h1B + ~leadOne + 1;

	assign shift_s = (leadShift > bigger_E + 1) ? (bigger_E + 1) : leadShift;

	assign tempE = (tempSum == 0) ? 8'h00 : (bigger_E + 1 + ~shift_s + 1);

	assign tempF = (tempE == 0) ? (tempSum<<(shift_s-1)) : (tempSum<<shift_s);
	
	assign normF_s = tempF[27:4];
	
	assign round_F = tempSum[27] ?
						(tempSum[3]) ?
						(|tempSum[2:0]) ? {1'b0, normF_s} + 1 : (tempSum[4]) ? {1'b0, normF_s} + 1 : {1'b0, normF_s}
						: {1'b0, normF_s}
		             	: (tempSum[26]) ?
						(tempSum[2]) ?
						(|tempSum[1:0]) ? {1'b0, normF_s} + 1 : (tempSum[3]) ? {1'b0, normF_s} + 1 : {1'b0, normF_s}
						: {1'b0, normF_s}
						: (tempSum[25]) ?
						(tempSum[1]) ?
						(tempSum[0]) ? {1'b0, normF_s} + 1 : (tempSum[2]) ? {1'b0, normF_s} +1 : {1'b0, normF_s}
						: {1'b0, normF_s}
						: {1'b0, normF_s};

	assign Sign_s = bigAlu[28];
	assign Exponent_s = round_F[24] ? tempE + 1 : tempE;
	assign Fraction_s = round_F[24] ? round_F[23:1] : round_F[22:0];

	assign s = {Sign_s, Exponent_s, Fraction_s};
endmodule