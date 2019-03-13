/* **************************************************************************
 * This file contain all functions that are connected with the MCU platform *
 * additional porting functions typical to dedicated hardware			    *
 ***************************************************************************/
#include "stm32f10x.h"
#include "misc.h"
#include <stdio.h>
#include <stdlib.h>

/* parameters, signal and ports definitions */

#define MFET_PORT				GPIOB

#define MFET_BUFF_DIR			GPIO_Pin_6
#define MFET_BUFF_CS			GPIO_Pin_7

#define MFET_1					GPIO_Pin_14		//10A	- 10000	miliamps
#define MFET_2					GPIO_Pin_15		//1A	- 1000	miliamps
#define MFET_3					GPIO_Pin_11		//0A1	- 100	miliamps
#define MFET_4					GPIO_Pin_10		//0A01	- 10	miliamps
#define MFET_5					GPIO_Pin_9		//0A001	- 1		miliamp
#define MFET_6					GPIO_Pin_8		//0A0001- 100	microamps

#define RELAY					GPIO_Pin_13
#define	BUZZER					GPIO_Pin_12

#define MOD_0					GPIO_Pin_1		//modes of operation
#define MOD_1					GPIO_Pin_0		//

/*-----------------------------------------------------------------*/

#define RELAY_ON				GPIO_SetBits(MFET_PORT, RELAY);
#define RELAY_OFF				GPIO_ResetBits(MFET_PORT, RELAY);

#define BUZZER_ON				GPIO_SetBits(MFET_PORT, BUZZER);
#define BUZZER_OFF				GPIO_ResetBits(MFET_PORT, BUZZER);

#define LEDMod0_ON				GPIO_ResetBits(MFET_PORT, MOD_0);
#define LEDMod0_OFF				GPIO_SetBits(MFET_PORT, MOD_0);

#define LEDMod1_ON				GPIO_ResetBits(MFET_PORT, MOD_1);
#define LEDMod1_OFF				GPIO_SetBits(MFET_PORT, MOD_1);

/*----------------------------------------------------------------*/

void Set_Range(int value);				// Read comments at function body
void Hardware_Init(void);

void NVIC_Configuration(void);
void GPIO_Configuration(void);
void RCC_Configuration(void);
void ADC_Configuration(void);
void DAC_Configuration(void);					// channel1 DAC1
void SysTick_Configuration(void);
void USART_Configuration(void);
u16 ReadADC1(u8 channel);
void WriteDAC1_CH1(u16 value);

void USARTSend_Str(char *str);
void USARTSend_Int(u8 byte);
void USARTSend_Val(unsigned int number, u8 conv);						// if conv = 1 then number will be multiplied by 0.807 to give value in milivolts, conv = 0 will stay as it is

/* ------ variables -------*/
