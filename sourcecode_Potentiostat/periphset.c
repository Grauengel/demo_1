/*
 * periphset.c
 *
 *  Created on: Sep 21, 2011
 *      Author: MdG
 */

#include "periphset.h"
#include <avr/io.h>
#include <util/delay.h>

uint8_t unkn[] = ("unknown command");

void per_init(void)
{
	DDRD |= (1<<PD1);					// TXD out
	DDRD &= ~(1<<PD0);					// RXD in

	DDRD |= (1<<PD5);					// OC1A out
	DDRB |= (1<<PB3);					// OC0 out

	DDRB &= ~(1<<PB0);					// ADC0 in
	DDRB &= ~(1<<PB1);					// ADC1 in

	// TIMER0 in PWM mode

	TCCR0 |= (1<<WGM01)|(1<<WGM00);		// Fast PWM
	TCCR0 |= (1<<COM01)|(1<<COM00);		// clear OC0 at top (default)
	TCCR0 |= (1<<CS00);					// timer on (no prescaling)

	// TIMER1 in PWM mode

	TCCR1A |= (1<<WGM11)|(1<<WGM10);	// 10 bit fast PWM
	TCCR1B |= (1<<WGM12);				// (up)
	TCCR1B |= (1<<CS10);				// timer on (no prescaling)
	TCCR1A |= (1<<COM1A1)|(1<<COM1A0);	// clear OC1A at top (default)
}

void UART_init(unsigned int baud)
{
	UBRRH = (uint8_t)(baud>>8);
	UBRRL = (uint8_t)baud;

	UCSRB |= (1<<RXEN)|(1<<TXEN);
	UCSRC |= (1<<URSEL)|(3<<UCSZ0);		// frame format: 8bits 1stop bit

	UCSRA |= (1<<U2X);

	PORTD |= (1<<PD1);
}

void UART_putchar(char c)									// TRANSMISSSION
{
  UDR = c;													// put c to UDR register
  loop_until_bit_is_set(UCSRA,TXC);							// wait for end of transmission
  UCSRA = _BV(TXC);											// set TXC bit in USR
}

char UART_getchar(void)										// RECIEVE
{
  loop_until_bit_is_set(UCSRA,RXC);							// wait for end of receiving
  UCSRA = _BV(RXC);											// clear RXC bit in USR
  return UDR;												// return UDR
}

void UART_string(uint8_t* data, uint8_t nBytes)				// SEND STRING
{
register uint8_t i;

	if (!data) return;

	for(i=0; i<nBytes; i++)
	{
		UART_putchar(data[i]);
	}
}

void UART_nextline(void)									// CARRIAGE RETURN
{
	UART_putchar(0x0D);
}

uint8_t ReadChannel(uint8_t mux)
{
	uint8_t i;
	uint8_t result;

	ADCSRA |= (1<<ADPS2)|(1<<ADPS0);
	ADCSRA |= (1<<ADEN);

	ADMUX = mux;  // Set Channel Selection

	ADMUX |= (1<<ADLAR);

	ADCSRA |= (1<<ADSC);
	while (ADCSRA & (1<<ADSC)) {
		;
	}

	for(i=0;i<4;i++)
	{
		ADCSRA |= (1<<ADSC);
		while (ADCSRA & (1<<ADSC)) {
			;
		}
		result = ADCH;
	}

	ADMUX &= 0xF7; // clear existing channel selection
	ADCSRA |= (1<<ADIF);
	ADCSRA &= (1<<ADEN);

	return result;
}

void cnt_up2down(void)
{
	TCCR0 |= (1<<COM01)|(1<<COM00);		// clear OC0 at top
	TCCR1A |= (1<<COM1A1)|(1<<COM1A0);	// clear OC1A at top
}

void cnt_down2up(void)
{
	TCCR0 |= (1<<COM01);				// set OCO at top
	TCCR0 &= ~(1<<COM00);

	TCCR1A |= (1<<COM1A1);				// set OC1A at top
	TCCR1A &= ~(1<<COM1A0);
}

void send_unkn(void)
{
	UART_string(unkn,15);
	UART_nextline();
}
