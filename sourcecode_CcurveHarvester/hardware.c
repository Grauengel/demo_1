#include "hardware.h"
#include "stm32f10x_conf.h"

int systic_base_ms			= 1;		// mili-seconds (ms) SysTick timebase should not be changed

void Set_Range(int value)
{
	GPIO_ResetBits(MFET_PORT, (MFET_1 | MFET_2 | MFET_3 | MFET_4 | MFET_5 | MFET_6));

		if(value==0) {}
		if(value==1) GPIO_SetBits(MFET_PORT, MFET_6);	// 0 - 100 microamps
		if(value==2) GPIO_SetBits(MFET_PORT, MFET_5);	// 0 - 1   miliamp
		if(value==3) GPIO_SetBits(MFET_PORT, MFET_4);	// 0 - 10  miliamps
		if(value==4) GPIO_SetBits(MFET_PORT, MFET_3);	// 0 - 100 miliamps
		if(value==5) GPIO_SetBits(MFET_PORT, MFET_2);	// 0 - 1   amp
		if(value==6) GPIO_SetBits(MFET_PORT, MFET_1);	// 0 - 10  amps
}

void USARTSend_Str(char *str)
{
	while (*str)
		{
		USART_SendData(USART1, *str++);
		while(USART_GetFlagStatus(USART1, USART_FLAG_TC) == RESET);
		}
}

void USARTSend_Int(u8 byte)
{
	USART_SendData(USART1, byte);
	while(USART_GetFlagStatus(USART1, USART_FLAG_TC) == RESET);
}

void USARTSend_Val(unsigned int number, u8 conv)
{
	if(conv==1) number = (number * 807) / 1000;
	USARTSend_Int((u8)(((number % 10000)/1000)+0x30));
	if(conv==1) USARTSend_Int(0x2C);
	USARTSend_Int((u8)(((number % 1000)/100)+0x30));
	USARTSend_Int((u8)(((number % 100)/10)+0x30));
	USARTSend_Int((u8)(((number % 10))+0x30));
}

u16 ReadADC1(u8 channel)
{
	// choosing the channel
	if (channel == 0)
	{
		ADC_RegularChannelConfig(ADC1, ADC_Channel_0, 1, ADC_SampleTime_239Cycles5);
	}
	if (channel == 1)
	{
		ADC_RegularChannelConfig(ADC1, ADC_Channel_1, 1, ADC_SampleTime_239Cycles5);
	}
	// Start the conversion
	ADC_SoftwareStartConvCmd(ADC1, ENABLE);

	// Wait until conversion completion
	while(ADC_GetFlagStatus(ADC1, ADC_FLAG_EOC) == RESET);

	return ADC_GetConversionValue(ADC1); // 0.807
}

void WriteDAC1_CH1(u16 value)
{
	DAC_SetChannel1Data(DAC_Align_12b_R, (u16)value);
}

void Hardware_Init(void)
{
	// mosfet keys control, buzzer and relay controls used as digital output

	GPIO_InitTypeDef GPIO_InitStructure;

    GPIO_InitStructure.GPIO_Pin = MFET_1 | MFET_2 | MFET_3 | MFET_4 | MFET_5 | MFET_6 | MFET_BUFF_DIR |
    								MFET_BUFF_CS | MOD_0 | MOD_1 | RELAY | BUZZER;
    GPIO_InitStructure.GPIO_Mode = GPIO_Mode_Out_PP;
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
    GPIO_Init(MFET_PORT, &GPIO_InitStructure);

    GPIO_SetBits(MFET_PORT, MOD_0 | MOD_1);						//	Initialization as default off when is H
    GPIO_ResetBits(MFET_PORT, (MFET_BUFF_DIR | MFET_BUFF_CS));	//  Output buffer configuration as always on, dir a->b
}

void SysTick_Configuration(void)
{
	// SysTick will be clocked with f = 24MHz/8 = 3 MHz
	SysTick_CLKSourceConfig(SysTick_CLKSource_HCLK_Div8);

	// interrupt by delay_ms if the register have an value 18070 blinky pin gives 1,000 kHz
	// that suggest multiplying two times
	if(SysTick_Config ((18070*2) * systic_base_ms));
	{
		//USARTSend_Str("SysTick Error");
	}
}

void RCC_Configuration(void)
{
	RCC_DeInit();
	RCC_HSICmd(ENABLE);

	while(RCC_GetFlagStatus(RCC_FLAG_HSIRDY) == RESET);
	RCC_SYSCLKConfig(RCC_SYSCLKSource_HSI);

	FLASH_PrefetchBufferCmd(FLASH_PrefetchBuffer_Enable);

	// 0 for 24MHz
	FLASH_SetLatency(FLASH_Latency_0);

	RCC_HCLKConfig(RCC_SYSCLK_Div1);

	// Set core clock as 24MHz max speed (for the present processor)
	RCC_PCLK2Config(RCC_HCLK_Div1);

	// Set peripherals clock as 24MHz (in STM32 up to 36 MHz)
	RCC_PCLK1Config(RCC_HCLK_Div1);

	//PLLCLK = (8MHz/2) * 9 = 24 MHz (if HSI must be divided by two)
	RCC_PLLConfig(RCC_PLLSource_HSI_Div2, RCC_PLLMul_9);

	//Turn on the PLL
	RCC_PLLCmd(ENABLE);

	//Wait for PLL ready
	while(RCC_GetFlagStatus(RCC_FLAG_PLLRDY) == RESET);

	//Set PLL as the clock source
	RCC_SYSCLKConfig(RCC_SYSCLKSource_PLLCLK);

	//Wait for PLL to be a system clock
	while(RCC_GetSYSCLKSource() != 0x08);

	RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA |RCC_APB2Periph_GPIOB| RCC_APB2Periph_USART1, ENABLE);
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_DAC, ENABLE);
}

void NVIC_Configuration(void)
{
  NVIC_InitTypeDef NVIC_InitStructure;

  /* Enable the USARTx Interrupt */
  NVIC_InitStructure.NVIC_IRQChannel = USART1_IRQn;
  NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 0;
  NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0;
  NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;
  NVIC_Init(&NVIC_InitStructure);

  NVIC_SetPriority(SysTick_IRQn, 0x04);
}

void USART_Configuration(void)
{
  USART_InitTypeDef USART_InitStructure;

/* USART1 configuration ------------------------------------------------------*/
  /* USART1 configured as follow:
        - BaudRate = 115200 baud
        - Word Length = 8 Bits
        - One Stop Bit
        - No parity
        - Hardware flow control disabled (RTS and CTS signals)
        - Receive and transmit enabled
        - USART Clock disabled
        - USART CPOL: Clock is active low
        - USART CPHA: Data is captured on the middle
        - USART LastBit: The clock pulse of the last data bit is not output to
                         the SCLK pin
  */
  USART_InitStructure.USART_BaudRate = 115200;
  USART_InitStructure.USART_WordLength = USART_WordLength_8b;
  USART_InitStructure.USART_StopBits = USART_StopBits_1;
  USART_InitStructure.USART_Parity = USART_Parity_No;
  USART_InitStructure.USART_HardwareFlowControl = USART_HardwareFlowControl_None;
  USART_InitStructure.USART_Mode = USART_Mode_Rx | USART_Mode_Tx;

  USART_Init(USART1, &USART_InitStructure);

  /* Enable USART1 */
  USART_Cmd(USART1, ENABLE);
}

void GPIO_Configuration(void)
{
  GPIO_InitTypeDef GPIO_InitStructure;

  /* Configure USART1 Tx (PA.09) as alternate function push-pull */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_9;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF_PP;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_Init(GPIOA, &GPIO_InitStructure);

  /* Configure USART1 Rx (PA.10) as input floating */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_10;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IN_FLOATING;
  GPIO_Init(GPIOA, &GPIO_InitStructure);

  GPIO_InitStructure.GPIO_Pin =  GPIO_Pin_4;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AIN;
  GPIO_Init(GPIOA, &GPIO_InitStructure);

  RCC_APB2PeriphClockCmd(RCC_APB2Periph_USART1 | RCC_APB2Periph_GPIOA, ENABLE);
}

void ADC_Configuration(void)
{
	ADC_InitTypeDef ADC_InitStructure;
	GPIO_InitTypeDef GPIO_InitStructure;

	/* ADCCLK = PCLK2/1 = 24/2 = 12MHz*/
	RCC_ADCCLKConfig(RCC_PCLK2_Div2);

	/* ADC1 input pins */
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA, ENABLE);
	GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0 | GPIO_Pin_1;
	GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
	GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AIN;
	GPIO_Init(GPIOA, &GPIO_InitStructure);

	RCC_APB2PeriphClockCmd(RCC_APB2Periph_ADC1, ENABLE);

	/* ADC1 and ADC2 operate independently */
	ADC_InitStructure.ADC_Mode = ADC_Mode_Independent;
	/* Disable the scan conversion so we do one at a time */
	ADC_InitStructure.ADC_ScanConvMode = DISABLE;
	/* Don't do contimuous conversions - do them on demand */
	ADC_InitStructure.ADC_ContinuousConvMode = DISABLE;
	/* Start conversin by software, not an external trigger */
	ADC_InitStructure.ADC_ExternalTrigConv = ADC_ExternalTrigConv_None;
	/* Conversions are 12 bit - put them in the lower 12 bits of the result */
	ADC_InitStructure.ADC_DataAlign = ADC_DataAlign_Right;
	/* Say how many channels would be used by the sequencer */
	ADC_InitStructure.ADC_NbrOfChannel = 1;
	/* Now do the setup */
	ADC_Init(ADC1, &ADC_InitStructure);
	/* ADC1 Regular Channel  1*/
	//ADC_RegularChannelConfig(ADC1, ADC_Channel_1, 1, ADC_SampleTime_239Cycles5);

	/* Enable ADC1 */
	ADC_Cmd(ADC1, ENABLE);

	/* Enable ADC1 reset calibaration register */
	ADC_ResetCalibration(ADC1);
	/* Check the end of ADC1 reset calibration register */
	while(ADC_GetResetCalibrationStatus(ADC1));

	/* Start ADC1 calibaration */
	ADC_StartCalibration(ADC1);
	/* Check the end of ADC1 calibration */
	while(ADC_GetCalibrationStatus(ADC1));
}

void DAC_Configuration(void)
{
	DAC_InitTypeDef DAC_InitStructure;

	DAC_InitStructure.DAC_Trigger = DAC_Trigger_None;
	DAC_InitStructure.DAC_WaveGeneration = DAC_WaveGeneration_None;
	DAC_InitStructure.DAC_OutputBuffer = DAC_OutputBuffer_Disable;
	DAC_Init(DAC_Channel_1, &DAC_InitStructure);

	DAC_Cmd(DAC_Channel_1, ENABLE);

	DAC_SetChannel1Data(DAC_Align_12b_R, 0x0000);
}

