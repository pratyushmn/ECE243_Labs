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

                BL       CONFIG_TIMER // configure the Interval Timer
                BL       CONFIG_KEYS // configure the pushbutton KEYs port                        

				/* Enable IRQ interrupts in the processor */
				MOV R1, #0b01010011 // change bit 7 to zero so IRQ unmasked, Mode = SVC
				MSR CPSR_c, R1

				LDR R5, =0xFF200000 // LEDR base address

LOOP:                                    
                LDR      R3, COUNT 	// global variable
                STR      R3, [R5]   // write to the LEDR lights
                B        LOOP


/* Define the exception service routines */
SERVICE_IRQ:    
				PUSH     {R0-R7, LR}   

				/* get the interrupt ID from the GIC*/  
                LDR      R4, =0xFFFEC100 // GIC CPU interface base address
                LDR      R5, [R4, #0x0C] // read the ICCIAR (Interrupt Acknowledgement Register) in the CPU
KEYS_CHECK:                       
                CMP      R5, #73         // check the interrupt ID (Keys)
				BLEQ       KEY_ISR  
				
TIMER_CHECK:	
				CMP      R5, #72         // check the interrupt ID (Timer)    
                BLEQ      TIMER_ISR                                   

EXIT_IRQ:       
				STR      R5, [R4, #0x10] // write to End of Interrupt Register (ICCEOIR)
                POP      {R0-R7, LR}     
                SUBS     PC, LR, #4      // return from exception
				
				
KEY_ISR:	
		/* What to do when key press detected */
		PUSH     {R0-R7} 
		LDR R0, =0xFF200050 // base address of KEYs
		LDR R1, [R0, #0xC] // read edge capture register
		STR R1, [R0, #0xC] // clear the interrupt
		LDR R4, =FREQUENCY // frequency address
		LDR R6, =0xFF202000	// Interval timer base address

CHECK_KEY0:
		MOVS R3, #0x1
		ANDS R3, R1 // check for KEY0
		BEQ CHECK_KEY1
		LDR R0, =RUN // increment variable
		LDR R1, [R0]
		EOR R1, #1 // toggle the last bit in R0
		STR R1, [R0]
		B END_KEY_ISR

CHECK_KEY1:
		MOVS R3, #0x2
		ANDS R3, R1 // check for KEY1
		BEQ CHECK_KEY2

		// update frequency by doubling it
		LDR R5, [R4]
		LSL R5, R5, #1
		STR R5, [R4] // save new frequency

		// stop clock
		MOV R3, #0x8
		STR R3, [R6, #4]

		// change frequency on clock
		STR R5, [R6, #0x8]	// store the low half word of counter start value
		LSR R5, R5, #16		// LSR is synonym for MOV
		STR R5, [R6, #0xC]	// high half word of counter start value

		// resume clock
		MOV R3, #0x7
		STR R3, [R6, #4]

		B END_KEY_ISR

CHECK_KEY2:

		MOVS R3, #0x4
		ANDS R3, R1 // check for KEY2
		BEQ END_KEY_ISR
		
		// update frequency by halving it
		LDR R5, [R4]
		LSR R5, R5, #1
		STR R5, [R4] // save new frequency

		// stop clock
		MOV R3, #0x8
		STR R3, [R6, #4]

		// change frequency on clock
		STR R5, [R6, #0x8]	// store the low half word of counter start value
		LSR R5, R5, #16		// LSR is synonym for MOV
		STR R5, [R6, #0xC]	// high half word of counter start value

		// resume clock
		MOV R3, #0x7
		STR R3, [R6, #4]

		
END_KEY_ISR:
		POP     {R0-R7} 
		BX      LR // end interrupt

TIMER_ISR:
	/* What to do when timer goes past specified value */
	PUSH {R0-R7}
	LDR R1, =0xFF202000 // interval timer base address
	MOVS R0, #0
	STR R0, [R1] // clear the interrupt
	LDR R0, =COUNT // get counter
	LDR R1, [R0]
	LDR R2, RUN 
	ADD R1, R2 // increment counter by run value
	STR R1, [R0]
	B END_TIMER_ISR

END_TIMER_ISR:
		POP     {R0-R7} 
		BX LR   // end interrupt

/* Configure the KEYs to generate interrupts */
CONFIG_KEYS:
				PUSH {LR}
				// write to the pushbutton port interrupt mask register
				LDR R0, =0xFF200050 // pushbutton key base address
				MOV R1, #0xF // set interrupt mask bits
				STR R1, [R0, #0x8] // interrupt mask register is (base + 8)
				POP {PC}

/* Configure the Interval Timer to generate Interrupts*/
CONFIG_TIMER:
				PUSH {LR}
				LDR R0, =0xFF202000	// Interval timer base address
				LDR R1, =25000000		// 1/(100 MHz)×(25000000) = 250msec 
				STR R1, [R0, #0x8]	// store the low half word of counter start value
				LSR R1, R1, #16		// LSR is synonym for MOV
				STR R1, [R0, #0xC]	// high half word of counter start value

				// start the interval timer, enable its interrupts
				MOV R1, #0x7		// START = 1, CONT = 1, ITO = 1
				STR R1, [R0, #0x4]
				POP {PC}


/* BELOW IS THE CODE FOR CONFIG_GIC (GIVEN)) */		
		
				.include	"address_map_arm.s"
				.include "defines.s"
				.include	"interrupt_ID.s"

/* BELOW IS THE CODE FOR CONFIG_GIC (GIVEN)) */		
		
				.include	"address_map_arm.s"
				.include    "defines.s"
				.include	"interrupt_ID.s"

/* 
 * Configure the Generic Interrupt Controller (GIC)
*/
				.global	CONFIG_GIC
CONFIG_GIC:
				PUSH		{LR}
    			/* Configure the A9 Private Timer interrupt, FPGA KEYs, and FPGA Timer
				/* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
				MOV		R0, #INTERVAL_TIMER_IRQ
    			MOV		R1, #CPU0
    			BL			CONFIG_INTERRUPT
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

/*Global variables*/
.global  COUNT
COUNT:            .word    0x0 // used by timer
				  
.global  RUN // used by pushbutton KEYs
RUN:              .word    0x1 // initial value to increment COUNT

.global FREQUENCY // current clock FREQUENCY
FREQUENCY:		.word 25000000 // initial frequency

.end
