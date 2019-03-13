/*
 * periphset.h
 *
 *  Created on: Sep 21, 2011
 *      Author: MdG
 */

#ifndef PERIPHSET_H_
#define PERIPHSET_H_

/* **************** GENERAL ****************/

#include <avr/io.h>
#define F_CPU 16000000UL					// uC clock frequency

/* **************** USART SECTION *********/

#define BAUD 9600
#define MYUBRR (F_CPU/8/BAUD-1)				// equation for F_CPU 16000000 u2x = 1

void UART_init(unsigned int ubrr);
void UART_putchar(char c);
char UART_getchar(void);
void UART_string(uint8_t* data, uint8_t nBytes);
void UART_nextline(void);
void send_unkn(void);

/* **************** ADC SECTION **********/

uint8_t ReadChannel(uint8_t mux);

/* *************** REST OF PERIFERALS SECTION (PWM) *************** */

void per_init(void);
void cnt_up2down(void);
void cnt_down2up(void);

/********************************************************************/

#endif /* PERIPHSET_H_ */
