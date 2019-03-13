/*******************************************************************************
  * @title   main.c
  * @author  l.jozwiak@wipos.p.lodz.pl
  * @date    10 Apr 2013
  * @brief   CV Curve Harvester V1.0 board
  ********************************************************************************/

#include "stm32f10x.h"
#include "stm32f10x_conf.h"
#include "misc.h"
#include <stdio.h>
#include <stdlib.h>
#include "hardware.h"

/* Private function definitions -----------------------------------------------*/

void USART1_IRQHandler(void);
void SysTick_Handler(void);
void SysTick_Delay(int ms);

void Routine_Select(void);
void Routine_01(void);
void Routine_02(void);
void Routine_End(void);
void MOD0_Meas(u8 range);

void OCV_Capt(void);
void Meas_Capt(void);

void Calc_Param(u8 samp_tick);

void Report_Disp(u8 param);
void Welcome_Disp(void);

/* Private macro -------------------------------------------------------------*/

#define FEED	USARTSend_Str("\r\n");
#define TAB		USARTSend_Int(0x09);

/* Private variables ---------------------------------------------------------*/

/*  USART SECTION */
char RxBuf[16];
int RxIndex = 0;

int RxCFlag = 0;

/* SysTick SECTION */
int systick_cnt_ms = 0;				// count
int systick_comp_ms = 1000;			// and compare :) 1000 is only the initial value

/* MEASUREMENT SECTION */
u16	samples_num		= 3;			// how many samples in meas not more than 10
u8	points_num		= 25;			// for setting point from point-tab DAC1, 26 is fuckin zero
u8  range_cnt 		= 0;
u16 samples_cnt		= 0;

long sampling_delay = 1000;
long sampling_cnt	= 0;

u16 ocv_reg 	= 0;
u16 volt_reg	= 0;
u16 curr_reg	= 0;

u32 volt_sum 	= 0;
u32 curr_sum 	= 0;

u8 div_tab[26] = {0xFF, 0x90, 0x63, 0x4A, 0x3A, 0x2F, 0x27,
				  0x21, 0x1C, 0x19, 0x15, 0x13, 0x10, 0x0E,
				  0x0D, 0x0B, 0x0A, 0x09, 0x08, 0x07, 0x06,
				  0x05, 0x04, 0x03, 0x02, 0x01};					// table of dividers ln(x)

u16 point_tab [26];													// universal for ocv, volt and curr

u16 volt_tab[10];
u16 curr_tab[10];

signed int lin_dev		= 0;										// linearity deviation
u16 foll_dev			= 0;										// follower deviation

// flags

u8 busy_flag = 0;													// 1 - busy

// common strings

char relay_on[9]		= {"Relay ON:"};
char relay_off[10]		= {"Relay OFF:"};

/**************************INTERRUPT HANDLERS****************/

void USART1_IRQHandler(void)
{
    if (USART_GetITStatus(USART1, USART_IT_RXNE) != RESET)
	{
			RxBuf[RxIndex++] = USART_ReceiveData(USART1);

			if(RxBuf[RxIndex-1] == 0x0D)							// if the last element of string will contain ASCI CR (Carriage Return) code
			{
				RxCFlag = 1;										// string received flag
			    RxIndex = 0;
			}
	}
}

/*		PROBABLY THE MOST IMPORTANT FUNCTION		*/
void SysTick_Handler(void)
{
	systick_cnt_ms++;

	if(systick_cnt_ms == systick_comp_ms)
	{
		busy_flag = 0;
		systick_cnt_ms = 0;
	}
}

void SysTick_Delay(int ms)
{
	busy_flag = 1;
	systick_comp_ms = ms;
	systick_cnt_ms = 0;
	while(busy_flag)
	{
		// do nothing
	}
}

/********************************************
 *        This is main body section         *
 ********************************************/

int main(void)
{
    RCC_Configuration();
    NVIC_Configuration();
    GPIO_Configuration();
    USART_Configuration();
    ADC_Configuration();
    DAC_Configuration();
    SysTick_Configuration();

    Hardware_Init();
    Welcome_Disp();

    USART_ITConfig(USART1, USART_IT_RXNE, ENABLE);

    Routine_Select();

    while(1)
    {
    	//
    }
}

void Welcome_Disp(void)
{
	USARTSend_Str(" ************************************"); FEED;
	USARTSend_Str("*   CV Curve Harvester  ver. 0.2   *"); FEED;
	USARTSend_Str("*   pemfc.org 	         by L.J.   *"); FEED;
	USARTSend_Str("************************************"); FEED;
}

void Routine_Select(void)
{
	USARTSend_Str("Select Mode:"); FEED;
	USARTSend_Str("0 - Scanning Mode"); FEED;
	USARTSend_Str("1 - Depletion/ Condition mode"); FEED; FEED;

    while(1)
	{
		if(RxCFlag)
		{
			if(RxBuf[0] == '0')
			{
				RxCFlag = 0;
				USARTSend_Str("Mode 0 - Scanning Mode"); FEED;
				Routine_01();
			}

			if(RxBuf[0] == '1')
			{
				RxCFlag = 0;
				USARTSend_Str("Mode 1 - Depletion/Condition mode"); FEED;
				Routine_02();
			}

			USARTSend_Str("Invalid entry \r\n");
			FEED;

			RxCFlag = 0;
		}
	}
}

void Routine_01(void)
{
	LEDMod0_ON
	USARTSend_Str("Device is ready, connect cables"); FEED;
	USARTSend_Str("and input '0' when ready"); FEED;

	u8 flag = 1;
	u8 i;

	while(flag)
	{
		if(RxCFlag)
				{
					if(RxBuf[0] == '0')
					{
						RxCFlag = 0;
						flag = 0;
					}
				}
	}

	RELAY_ON;
	FEED;
	USARTSend_Str(relay_on); FEED;
	SysTick_Delay(1000);

	OCV_Capt();
	Report_Disp(1);

	for(i=1;i<7;i++)
	{
		MOD0_Meas(i);
	}

	Set_Range(0);
	LEDMod0_OFF;
	Routine_End();
}
void MOD0_Meas(u8 range)
{
	u8 i, j ,k;
	samples_cnt = 0;
	u8 flag = 0;

	Set_Range(range);
	FEED; FEED; USARTSend_Str("Range is : "); USARTSend_Val(range, 0); FEED; FEED;
	SysTick_Delay(sampling_delay);

	USARTSend_Str("Nr. "); TAB; USARTSend_Str("U [V] "); TAB; USARTSend_Str("I [R/V]"); TAB; USARTSend_Str("F dev"); TAB; USARTSend_Str("  L dev"); FEED;
	USARTSend_Str("----"); TAB; USARTSend_Str("------"); TAB; USARTSend_Str("-------"); TAB; USARTSend_Str("-----"); TAB; USARTSend_Str("  -----"); FEED;

	for(i=26;i>0;i--)
	{
		DAC_SetChannel1Data(DAC_Align_12b_R, (u16)point_tab[i-1]);
		USARTSend_Val((samples_cnt+1), 0); TAB;											// printing sample number
		samples_cnt++;

		for(j=0;j<samples_num;j++)														// samples num = 3 -> 3 points
		{
			SysTick_Delay(10);															// between oversamples

			volt_tab[j] = ReadADC1(1);
			volt_sum = volt_sum + volt_tab[j];
			curr_tab[j] = ReadADC1(0);
			curr_sum = curr_sum + curr_tab[j];
		}

		/*02.10.13*/
		for(j=0;j<60;j++)							// minuta odstêpu
		{
			SysTick_Delay(1000);
		}

		/*02.10.13*/

		volt_reg = volt_sum / samples_num;
		volt_sum = 0;
		curr_reg = curr_sum / samples_num;
		curr_sum = 0;

		for(k=0;k<samples_num;k++) {lin_dev = lin_dev + (volt_tab[samples_num-1] - volt_tab[k]);}

		USARTSend_Val(volt_reg, 1); TAB;												// printing voltage
		USARTSend_Val(curr_reg, 1); TAB;												// printing current-voltage

		USARTSend_Val((point_tab[i-1]-curr_reg), 0); TAB;								// follower deviation

		if(lin_dev>=0) {USARTSend_Str(" +"); USARTSend_Val(lin_dev, 1);}				// linear deviation
		else {USARTSend_Str(" -"); USARTSend_Val((lin_dev*(-1)), 1);}

		lin_dev = 0;

		FEED;

	}

	Set_Range(0);
	DAC_SetChannel1Data(DAC_Align_12b_R, 0x0000);

	flag = 1;

	while(flag)
					{
						USARTSend_Str("Input '0' to continue when the values will be stable = "); TAB;		// the carrier is not return

						for(j=0;j<samples_num;j++)														// samples num = 3 -> 3 points
						{
							SysTick_Delay(10);															// between oversamples

							volt_tab[j] = ReadADC1(1);
							volt_sum = volt_sum + volt_tab[j];
							curr_tab[j] = ReadADC1(0);
							curr_sum = curr_sum + curr_tab[j];
						}

						volt_reg = volt_sum / samples_num;
						volt_sum = 0;
						curr_reg = curr_sum / samples_num;
						curr_sum = 0;

						USARTSend_Val(volt_reg, 1); TAB;												// printing voltage
						USARTSend_Val(curr_reg, 1); TAB;

						SysTick_Delay(1000);

						for(j=0;j<68;j++)
						{
							USARTSend_Int(0x08);						// pointer at the end of last line, deleting line
						}

						if(RxCFlag)
								{
									if(RxBuf[0] == '0')
									{
										RxCFlag = 0;
										flag = 0;
									}
								}
					}
	FEED;

	i = 0;
}

void Routine_02(void)
{
	LEDMod1_ON;
	USARTSend_Str("Device is ready, connect cables"); FEED;
	USARTSend_Str("and input '1' when ready"); FEED;

	u8 flag = 1;
	u8 i;

		while(flag)
		{
			if(RxCFlag)
					{
						if(RxBuf[0] == '1')
						{
							RxCFlag = 0;
							flag = 0;
						}
					}
		}

		RELAY_ON;
		FEED;
		USARTSend_Str(relay_on); FEED;
		SysTick_Delay(1000);

		OCV_Capt();
		Report_Disp(1);
		Report_Disp(2);

		RELAY_OFF;
		USARTSend_Str(relay_off); FEED;

		USARTSend_Str("Choose range and point"); FEED;
		USARTSend_Str("in #/## format (range/point)"); FEED;

		flag = 1;

		while(flag)
		{
			if(RxCFlag)
					{
						if(RxBuf[0] > 0x36)								// 6 decimal
						{
							RxCFlag = 0;
							USARTSend_Str("Error: Range out of Range"); FEED;
						}

						if(RxBuf[0] < 0x31)								// 6 decimal
						{
							RxCFlag = 0;
							USARTSend_Str("Error: Range lower than 1"); FEED;
						}
						else{range_cnt = (RxBuf[0] - 0x30);}

						if((((RxBuf[2] - 0x30)*10) + (RxBuf[3]-0x30)) > 26)
						{
							RxCFlag = 0;
							USARTSend_Str("Error: Point must be between 1 - 26"); FEED;
						}

						if((((RxBuf[2] - 0x30)*10) + (RxBuf[3]-0x30)) <= 26)
						{
							RxCFlag = 0;
							points_num = ((RxBuf[2] - 0x30)*10) + (RxBuf[3]-0x30);
							flag = 0;
						}
					}
		}

		//USARTSend_Val(range_cnt, 0); FEED;
		//USARTSend_Val(points_num, 0); FEED;

		FEED;
		USARTSend_Str("Input number of samples not much than 9999");FEED
		USARTSend_Str("and time interval in seconds ####/### (samples/seconds");FEED;
		FEED;

		flag = 1;

		while(flag)
			{
				if(RxCFlag)
					{
						int smp = ((RxBuf[0]-0x30)*1000) + ((RxBuf[1]-0x30)*100) + ((RxBuf[2]-0x30)*10) + (RxBuf[3]-0x30);
						int tim = ((RxBuf[5]-0x30)*100) + ((RxBuf[6]-0x30)*10) + (RxBuf[7]-0x30);

						if(smp > 9999)								// 6 decimal
						{
							RxCFlag = 0;
							USARTSend_Str("Error: Value to big"); FEED;
						}

						if(tim > 999)
						{
							RxCFlag = 0;
							USARTSend_Str("Error: Time is to high"); FEED;
						}

						if(smp < 9999)
						{
							RxCFlag = 0;
							sampling_delay = tim;
							samples_num = smp;
							flag = 0;
						}
					}
			}

		//USARTSend_Val(samples_num, 0); FEED;

		Set_Range(range_cnt);
		DAC_SetChannel1Data(DAC_Align_12b_R, (u16)volt_tab[points_num]);
		RELAY_ON;
		USARTSend_Str(relay_on); FEED;
		SysTick_Delay(1000);

		int sample_memo = ocv_reg;
		int samp_del_memo = sampling_delay;

		USARTSend_Str("Sample every: ");USARTSend_Val(sampling_delay, 0); USARTSend_Str(" seconds"); FEED;

		USARTSend_Str("No."); TAB; USARTSend_Str("U [V]"); TAB; USARTSend_Str("Delta [V]"); FEED;

		for(i=0;i<=samples_num;i++)														// samples num = 3 -> 3 points
				{
					while(sampling_delay)
					{
						SysTick_Delay(1000);
						sampling_delay--;
					}

					volt_reg = ReadADC1(1);
					USARTSend_Val((i+1), 0); TAB; USARTSend_Val(volt_reg, 1); TAB; USARTSend_Val((sample_memo - volt_reg), 1); FEED;
					sample_memo = volt_reg;
					sampling_delay = samp_del_memo;
				}

		USARTSend_Str("Measurements END:"); FEED;

		RELAY_OFF;
		USARTSend_Str(relay_off); FEED;

		LEDMod1_OFF;
		Routine_End();
}

void OCV_Capt(void)
{
	u8 i = 0;

	for(i=0;i<5;i++)
	{
		volt_tab[i] = ReadADC1(1);

		SysTick_Delay(1000);															// wait 1 S
	}

	for(i=0;i<5;i++) volt_sum = volt_sum + volt_tab[i];									// calculating average value
	ocv_reg = (volt_sum / 5);
	volt_sum = 0;

	for(i=0;i<4;i++) lin_dev = lin_dev + (volt_tab[4] - volt_tab[i]);					// calculating linear deviation
	for(i=0;i<26;i++) point_tab[i] = ((div_tab[i] * ocv_reg) / 0xFF);					// calculating points, this is only OCV function
																						// should do
}

void Routine_End(void)
{
	RELAY_OFF;
	USARTSend_Str(relay_off); FEED;
	USARTSend_Str("Press RESET to continue");
	while(1)
	{
		//
	}

}

void Report_Disp(u8 param)
{
	if(param==1)																		// reporting ocv value and linear deviation
	{
		USARTSend_Str("OCV Value = "); USARTSend_Val(ocv_reg, 1); USARTSend_Str(" V ");
		TAB;
		USARTSend_Str("linear deviation = ");
		if(lin_dev>=0) {USARTSend_Str(" +"); USARTSend_Val(lin_dev, 1);}
		else {USARTSend_Str(" -"); USARTSend_Val((lin_dev*(-1)), 1);}
		USARTSend_Str(" V ");
		FEED;
	}
	if(param==2)																		// reporting points
	{
		u8 point_counter = 0;

		u8 i = 9;
		u8 j = 0;
		u8 z = 3;

		FEED;
		USARTSend_Str("The points are:");
		FEED;

		while(z)
		{
			while(point_counter < i)													// i < 9 ; i < 17 ; i < 27
			{
				USARTSend_Val(point_counter, 0);
				USARTSend_Int(0x09);
				point_counter++;
			}
			FEED;
			point_counter = j;

			while(point_counter < i)
			{
				USARTSend_Str("------");
				USARTSend_Int(0x09);
				point_counter++;
			}
			FEED;
			point_counter = j;

			while(point_counter < i)
			{
				USARTSend_Val(point_tab[point_counter], 1);
				USARTSend_Int(0x09);
				point_counter++;
			}
			FEED;
			FEED;

			j = j + 9;
			point_counter = j;
			i = i + 9;
			z--;
		}
	}
	if(param==3)
	{
		//
	}
}
