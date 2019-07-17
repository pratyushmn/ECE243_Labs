				.include 	"exceptions.s"

				
				.section .vectors, "ax"  
                B        _start              // reset vector
                B        SERVICE_UND         // undefined instruction vector
                B        SERVICE_SVC         // software interrupt vector
                B        SERVICE_ABT_INST    // aborted prefetch vector
                B        SERVICE_ABT_DATA    // aborted data vector
                .word    0                   // unused vector
                B        SERVICE_IRQ         // IRQ interrupt vector
                B        SERVICE_FIQ         // FIQ interrupt vector

                .text    
                .global  _start 

_start:                                  
				/* Set up stack pointers for IRQ and SVC processor modes */

				MOV R1, #0b11010010
				MSR CPSR_c, R1 // change to IRQ mode with interrupts disabled
				LDR SP, =0xFFFFFFFC // set IRQ stack to top of A9 on-chip memory
			   
				MOV R1, #0b11010011
			    MSR CPSR_c, R1 // change to SVC mode with interrupts disabled
				LDR SP, =0x3FFFFFFC // set SVC stack to top of DDR3 memory

                BL       CONFIG_GIC      // configure the ARM generic
                                         // interrupt controller

                BL CONFIG_KEYS // configure the KEYS for interrupts                         

				/* Enable IRQ interrupts in the processor */
				MOV R1, #0b01010011 // change bit 7 to zero so IRQ unmasked, MODE = SVC
				MSR CPSR_c, R1

LOOP:                                    
                B        LOOP            // main program does nothing except wait for exception

/* Define the exception service routines */

SERVICE_IRQ:    
				PUSH     {R0-R7, LR}   

				/* get the interrupt ID from the GIC*/  
                LDR      R4, =0xFFFEC100 // GIC CPU interface base address
                LDR      R5, [R4, #0x0C] // read the ICCIAR (Interrupt Acknowledgement Register) in the CPU
                                         

KEYS_CHECK:                       
                CMP      R5, #73         // check the interrupt ID

UNEXPECTED:     
				BNE      UNEXPECTED      // if not recognized, stop here
                BL       KEY_ISR         

EXIT_IRQ:       
				STR      R5, [R4, #0x10] // write to the End of Interrupt
                                         // Register (ICCEOIR)
                POP      {R0-R7, LR}     
                SUBS     PC, LR, #4      // return from exception
				
				
KEY_ISR:	

		/* Used to describe what happens when key press detected */
		PUSH     {R0-R11} 
		LDR R0, =0xFF200050 // base address of KEYs
		LDR R1, [R0, #0xC] // read edge capture register
		STR R1, [R0, #0xC] // clear the interrupt
		LDR R2 , =0xFF200020 //base address for HEX
		LDR R7, =HEX	//Hex values for 0-3

		
CHECK_KEY0:

		MOVS R3, #0x1
		ANDS R3, R1    // check for KEY0
		BEQ CHECK_KEY1 // jumps to next check subroutine if the and instruction gives 0 (ie. the first bit in R1 did not equal 1)
		LDRB R5,[R7]   // R5 contains HEX value for 0
		LDRB R4,[R2]   // loads current data from HEX0
		CMP R5,R4 	   // check to see if it is currently displaying 0
		LDREQ R5,BLANK // if it is, then load blank
		STRB R5, [R2]  // display 0/blank on HEX0 based on above check
		B END_KEY_ISR
		
CHECK_KEY1:

		MOVS R3, #0x2
		ANDS R3, R1		// check for KEY1
		BEQ CHECK_KEY2
		LDRB R5,[R7,#1]
		LDRB R4,[R2,#1] // loads current data from HEX1
		CMP R5,R4
		LDREQ R5,BLANK
		STRB R5, [R2,#1] // display 1/blank on HEX1 based on above check
		B END_KEY_ISR
		
CHECK_KEY2:

		MOVS R3, #0x4
		ANDS R3, R1		// check for KEY2
		BEQ CHECK_KEY3
		LDRB R5,[R7,#2]
		LDRB R4,[R2,#2] // loads current data from HEX2
		CMP R5,R4
		LDREQ R5,BLANK
		STRB R5, [R2,#2] // display 2/blank on HEX2 based on above check
		B END_KEY_ISR
		
CHECK_KEY3:

		MOVS R3, #0x8
		ANDS R3, R1		// check for KEY3
		BEQ END_KEY_ISR
		LDRB R5,[R7,#3]
		LDRB R4,[R2,#3] // loads current data from HEX3
		CMP R5,R4
		LDREQ R5,BLANK
		STRB R5, [R2,#3] // display 3/blank on HEX3 based on above check
		B END_KEY_ISR
		
END_KEY_ISR:
		POP     {R0-R11} 
		BX LR

/* Configure the KEYs to generate interrupts */
CONFIG_KEYS:
				PUSH {LR}
				// write to the pushbutton port interrupt mask register
				LDR R0, =0xFF200050 // pushbutton key base address
				MOV R1, #0xF // set interrupt mask bits
				STR R1, [R0, #0x8] // interrupt mask register is (base + 8)
				POP {PC}
		
/* BELOW IS THE CODE FOR CONFIG_GIC (GIVEN)) */		
		
				.include	"address_map_arm.s"
				.include "defines.s"
				.include	"interrupt_ID.s"

/* 
 * Configure the Generic Interrupt Controller (GIC)
*/
				.global	CONFIG_GIC
CONFIG_GIC:
				PUSH		{LR}
    			/* Configure the A9 Private Timer interrupt, FPGA KEYs, and FPGA Timer
				/* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
    			MOV		R0, #KEYS_IRQ
    			MOV		R1, #CPU0
    			BL			CONFIG_INTERRUPT

				/* configure the GIC CPU interface */
    			LDR		R0, =0xFFFEC100		// base address of CPU interface
    			/* Set Interrupt Priority Mask Register (ICCPMR) */
    			LDR		R1, =0xFFFF 			// enable interrupts of all priorities levels
    			STR		R1, [R0, #0x04]
    			/* Set the enable bit in the CPU Interface Control Register (ICCICR). This bit
				 * allows interrupts to be forwarded to the CPU(s) */
    			MOV		R1, #1
    			STR		R1, [R0]
    
    			/* Set the enable bit in the Distributor Control Register (ICDDCR). This bit
				 * allows the distributor to forward interrupts to the CPU interface(s) */
    			LDR		R0, =0xFFFED000
    			STR		R1, [R0]    
    
    			POP     	{PC}
/* 
 * Configure registers in the GIC for an individual interrupt ID
 * We configure only the Interrupt Set Enable Registers (ICDISERn) and Interrupt 
 * Processor Target Registers (ICDIPTRn). The default (reset) values are used for 
 * other registers in the GIC
 * Arguments: R0 = interrupt ID, N
 *            R1 = CPU target
*/
CONFIG_INTERRUPT:
    			PUSH		{R4-R5, LR}
    
    			/* Configure Interrupt Set-Enable Registers (ICDISERn). 
				 * reg_offset = (integer_div(N / 32) * 4
				 * value = 1 << (N mod 32) */
    			LSR		R4, R0, #3							// calculate reg_offset
    			BIC		R4, R4, #3							// R4 = reg_offset
				LDR		R2, =0xFFFED100
				ADD		R4, R2, R4							// R4 = address of ICDISER
    
    			AND		R2, R0, #0x1F   					// N mod 32
				MOV		R5, #1								// enable
    			LSL		R2, R5, R2							// R2 = value

				/* now that we have the register address (R4) and value (R2), we need to set the
				 * correct bit in the GIC register */
    			LDR		R3, [R4]								// read current register value
    			ORR		R3, R3, R2							// set the enable bit
    			STR		R3, [R4]								// store the new register value

    			/* Configure Interrupt Processor Targets Register (ICDIPTRn)
     			 * reg_offset = integer_div(N / 4) * 4
     			 * index = N mod 4 */
    			BIC		R4, R0, #3							// R4 = reg_offset
				LDR		R2, =0xFFFED800
				ADD		R4, R2, R4							// R4 = word address of ICDIPTR
    			AND		R2, R0, #0x3						// N mod 4
				ADD		R4, R2, R4							// R4 = byte address in ICDIPTR

				/* now that we have the register address (R4) and value (R2), write to (only)
				 * the appropriate byte */
				STRB		R1, [R4]
    
    			POP		{R4-R5, PC}


HEX:
	.byte 0b00111111 //0
    .byte 0b00000110 //1
    .byte 0b01011011 //2
    .byte 0b01001111 //3
	
BLANK: 
	.word 0b0000000 // blank

