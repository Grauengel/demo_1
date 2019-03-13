/*
 * main.c
 *
 *  Created on: Sep 21, 2011
 *      Author: MdG
 */

#include "periphset.h"
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

uint8_t ready[] = ("READY");

//void start(void);

uint16_t i;								// counter 0
uint8_t j;								// counter 1
uint16_t interval;						// time interval in miliseconds
uint16_t current;						// ADC value variable
char comm_rec ;							// command received

int main(void)
{
	per_init();
	UART_init(MYUBRR);
	cnt_down2up();						// default is up2down (look bodyfunction)
	interval = 100;						// default interval
	UART_string(ready,5);				// send D


	while(1)
	{
		return 0;
	}
}

void start(void)
{
	{
			for(i=0;i<1023;i++)		  			// for i in full range of PWM (10 bits)
			{
				if (i<255)						// but less than 8 bits
				{
					OCR0 = i;					// put i to OCR0
					OCR1AL = i;					// and to the lsb of OC1A
					UART_putchar(i);			// finally send via usart
					UART_putchar(0x20);			// space
					current = ReadChannel(0);	// read current
					UART_putchar(current);		// send current
					UART_nextline();
					_delay_ms(interval);
				}
				else						// for more than 8 bits
				{
					j = (i>>8);				// put 8 times moved i to j (take hsb of i)
					OCR1AH = j;				// put j to hsb of OC1A
					UART_putchar(j);
					OCR1AL = i;				// put j to lsb of OC1A
					UART_putchar(i);
					UART_putchar(0x20);			// space
					current = ReadChannel(0);	// read current
					UART_putchar(current);		// send current
					UART_nextline();
					_delay_ms(interval);
				}
			}
			for(i=1023;i;i--)				// for i in full range of PWM (10 bits)
			{
				if (i<255)
				{
					OCR0 = i;					// put i to OCR0
					OCR1AL = i;					// and to the lsb of OC1A
					UART_putchar(i);			// finally send via usart
					UART_putchar(0x20);			// space
					current = ReadChannel(0);	// read current
					UART_putchar(current);		// send current
					UART_nextline();
					_delay_ms(interval);
				}
				else
				{
					j = (i>>8);				// put 8 times moved i to j (take hsb of i)
					OCR1AH = j;				// put j to hsb of OC1A
					UART_putchar(j);
					OCR1AL = i;				// put j to lsb of OC1A
					UART_putchar(i);
					UART_putchar(0x20);			// space
					current = ReadChannel(0);	// read current
					UART_putchar(current);		// send current
					UART_nextline();
					_delay_ms(interval);
				}
			}
	}
}

SIGNAL(SIG_UART_RECV)
{

	cli();								// INTERRUPTS OFF
	comm_rec = UART_getchar();			// take char from UART

	switch (comm_rec)
	{
		case 0x53:							// S
		{
			start();
			break;
		}
		case 0x54:							// T
		{
			comm_rec = UART_getchar();
			if (comm_rec>30)
			{
				interval = (comm_rec - 0x30) * 1000;
			}
			else
			{
				send_unkn();
			}
			break;
		}
		case 0x44:							// D
		{
			comm_rec = UART_getchar();

			if (comm_rec = 0x44)
			{
				cnt_up2down();
			}
			else
			{
				if (comm_rec = 0x55)
				{
					cnt_down2up();
				}
				else
				{
					send_unkn();
					break;
				}
			}
		break;
		}

	default:							//--------------------------------------------------------------------
		{
			send_unkn();
			break;
		}
	}

	sei();								// INTERRUPTS ON
}
